# Привычка-воздержание: второй вычисляемый вид

For agentic workers: use the `superpowers:subagent-driven-development` skill to
execute this plan. Одна задача — один исполнитель, один коммит; исполнитель
читает **ровно одну** задачу и не обязан читать ни одной другой.

## Goal

Человек заводит привычку «не пить», «не листать ленту», «не курить», отмечает
редкие срывы — и видит, сколько дней он держится. Всё остальное приложение
считает само: чистый день не пишется вовсе, срыв делит оценку пополам, а
счётчик «дней без срыва» существует с того дня, когда человек пообещал, а не с
первой записи. Воздержание — **второй** житель слоя вычисляемых привычек, и
половина работы здесь состоит в том, чтобы механика, написанная под сон,
перестала быть сонной: перечисление по боковой таблице, сигнал инвалидации,
хуки жизненного цикла и импорт копии становятся видонезависимыми, а не
получают вторую копию с другим именем.

## Architecture

Четыре роли, ровно те же, что у сна («Конвейер» спецификации):

* **источник** — палец человека: тап по ячейке списка, тап по дню в
  календаре-редакторе, кнопка на карточке экрана привычки;
* **хранилище** — таблица `Lapses(habit, day, amount)` (миграция 103) и
  `LapseRepository`: строка есть **измеренная величина дня**, а не флаг срыва;
* **определение** — строка `HabitDefinitions` вида `abstinence` с
  `committed_from` и `payload`, несущим допуск и единицу; `Habit.definition`
  везёт её на живой модели, потому что `recompute()` зовут пятнадцать мест и
  ни одно не видит репозитория;
* **свод** — `AbstinenceSync`: журнал → значения дней через единственную дверь
  записи `DayWriter`, которая сама пересчитывает привычку и один раз объявляет
  об изменении.

Оценка: воздержание хранится как обычная числовая привычка `atMost` с целью,
равной допуску. Молчание есть успех даром — портированная ветвь at-most
стартует с `1.0` и превращает отсутствующий день в `max(0, -1) = 0`. Не даётся
портом ровно одно — половина: шаг порта аффинный и не может опустить оценку
больше чем на 5.2 % за день. Поэтому у `ScoreList` появляется мутируемое поле
`halvesOnLapse`, включаемое `applyLapseScoring` для вида `abstinence` и только
для него.

Счёт дней: `StreakList` получает `getCurrent(day)` и параметр
`silenceQualifies`, `Habit.recompute()` — нижнюю границу окна по дню
обязательства, а наружу торчит одна функция ядра
`int daysWithoutLapse(Habit habit, {LocalDate? asOf})`.

## Tech Stack

* Dart / Flutter; `packages/uhabits_core` — чистый Dart без `package:flutter`,
  `app/` — Flutter поверх него.
* sqlite3 через `packages/uhabits_core/lib/src/database/`, миграции —
  `extension_migrations.dart`, версия схемы — `appDatabaseVersion`.
* Тесты: `dart test` в ядре, `flutter test` в приложении; реестр правил —
  `docs/extensions/COMPUTED.md`, проверяется `dart tool/parity_coverage.dart
  --verify`; отступления от оригинала — `docs/parity/DEVIATIONS.md`.
* Локализация: `app/lib/l10n/app_en.arb` + `app_ru.arb`, `flutter gen-l10n`.

## Spec

`docs/superpowers/specs/2026-08-26-computed-habits-design.md`

## Global Constraints

Действуют в каждой задаче без исключения:

1. `HabitType` имеет ровно две записи. Ни один вычисляемый вид не заводит
   третью: воздержание хранится как числовая привычка.
2. `packages/uhabits_core` не импортирует `package:flutter`.
3. `docs/parity/FEATURES.md` не меняется — ни строкой, ни в одной задаче.
4. Каждое новое правило несёт префикс `computed.` и живёт в
   `docs/extensions/COMPUTED.md`.
5. Каждая строка интерфейса заводится сразу в `app_en.arb` **и** `app_ru.arb`.
6. `appDatabaseVersion` становится 103.

## Порядок исполнения

Порядок задач жёсткий, и он не совпадает с порядком разделов, в которых они
писались. Причин ровно три:

1. **4-ui-list не компилируется без ядра.** Ячейке списка нужны
   `AppScope.lapses` (задача 19), `AbstinenceSync` (задача 24) и
   `onComputedDataChanged` (задача 10). Поэтому весь раздел списка идёт
   последним из содержательных.
2. **5-create.5 обязан писать уже переименованный `onComputedDataChanged`.**
   Задача 10 снимает последнее вхождение `onSleepDataChanged` по `grep`; если
   редактор привычки пишет старое имя после неё, оно вернётся и файл перестанет
   собираться. Значит переименование — раньше редактора.
3. **`AppScope.open` правят три задачи, и только в одном порядке.** Задача 11
   (6-hooks.3) вводит `late final AppScope scope;` и приводит хвост метода
   дословно; задача 17 (3-streaks.6) поднимает объявление `definitions` выше
   цикла пересчёта; задача 19 (отложенный шаг 5 из 1-schema.3) вешает рядом
   `lapses`. Любой другой порядок даёт либо ненайденный текст, либо второе
   объявление `definitions` в той же области видимости.

Задача **1-schema.4** в план не входит: она писала тот же
`lapse_importer.dart`, тот же тест и то же правило `computed.backup#4`, что и
задача 22 (6-hooks.5), в которой вдобавок стоит проводка приложения. Из неё
перенесён один тест — «an importer with no journal to write to behaves as
upstream».

## Раздел «Схема и репозиторий срывов»


Решения, принятые здесь и обязательные для остальных разделов.

**Величина живёт в строке, допуск — в определении.** Спецификация говорит это
прямо дважды. Первый раз в блоке схемы: «У воздержания наоборот: `committed_from`
обязателен, а `payload` несёт **допуск и единицу**». Второй раз в «Воздержании как
втором»: «В **редакторе** можно задать „не более 30 минут“» — редактор правит
привычку, а не день, значит допуск есть свойство обязательства и применяется ко
всем дням, которые обязательство накрывает. Отсюда три следствия, каждое из
которых сломалось бы, если положить допуск в строку:

1. Понижение допуска с 30 до 10 обязано переоценить уже записанные дни. Допуск,
   вмороженный в строку, оставил бы вчера судимым по вчерашнему правилу.
2. Единица не может меняться от строки к строке: две строки в разных единицах
   несравнимы, и ни сумма, ни сравнение с допуском не имеют смысла. Единица
   названа один раз — в определении.
3. Обратное — «строка хранит суждение „это срыв“» — тоже отпадает: суждение есть
   функция от допуска, а допуск изменяем.

Поэтому `Lapses.amount` есть **измеренная величина дня** в единице привычки, а не
флаг срыва. Судит определение: `isAbstinenceLapse(definition, amount)`.

**Величина не меньше единицы.** Ноль записать нельзя: при допуске ноль условие
«за день не больше допуска» на нуле выполняется, и строка означала бы молчание,
притворившееся фактом. Молчание выражается отсутствием строки — ровно как
отсутствующий день у сна остаётся отсутствующим.

**Колонок ровно четыре — те, что в спецификации.** Ни `source`, ни `updated_at`:
источник сегодня один (палец человека), Screen Time спецификацией из работы
исключён, и выдумывать форму провенанса до того, как второй источник существует,
значит гадать. `SleepSessions` несёт эти колонки потому, что у сна два источника
были с первого дня.

**Индекс не нужен.** `primary key (habit, day)` на rowid-таблице даёт
`sqlite_autoindex_Lapses_1`, и он покрывает единственную форму чтения —
`habit = ? and day between ? and ?`. Суррогатного `id`, как у `SleepSessions`, нет
намеренно: на строку срыва ничто не ссылается.

**Последствие отката:** после первого запуска этой сборки файл несёт
`user_version` 103, `isKnownDatabaseVersion` его в сборке со 102 отвергает, и
`AppScope` уводит базу в карантин `<path>.invalid`, открывая пустую, — цена того
же рода, что уже принята за 100 и 102; копия, снятая до обновления, остаётся
читаемой.

**Версия 103, а не 102.** Текст спецификации кладёт `Lapses` в 102 — он
устарел: 102 уже уехала на живой телефон и создаёт `HabitDefinitions`.
Дописывать в отгруженную миграцию нельзя: у того, кто уже на 102, она не
выполнится второй раз.

### Task 1: миграция 103 — журнал срывов (1-schema.1)

**Файлы:**
- Изменить: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/database/extension_migrations.dart`
- Тест: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/database/extension_migrations_test.dart`
- Тест: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/platform/upgrade_102_to_103_test.dart`

**Интерфейсы:**
- Потребляет: `openAppSchemaDatabase()`, `openAppSchemaDatabaseAt(int)` из
  `packages/uhabits_core/test/helpers/test_database.dart` (обе уже есть).
- Даёт: таблицу `Lapses(habit, day, amount)` с каскадом и
  `const int appDatabaseVersion = 103`.

- [ ] **Шаг 1: написать падающий тест**

В `test/database/extension_migrations_test.dart` дописать импорт

```dart
import 'package:uhabits_core/src/database/sqlite3_database.dart';
```

и новую группу в конец `main()`:

```dart
  group('migration 103', () {
    test('creates the lapse journal, and a habit takes it with it', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);

      expect(appDatabaseVersion, 103, reason: 'computed.schema#4');
      expect(db.getVersion(), appDatabaseVersion, reason: 'computed.schema#4');
      expect(
        db.queryInt("select count(*) from sqlite_master "
            "where type = 'table' and name = 'Lapses'"),
        1,
        reason: 'computed.schema#4',
      );

      // The cascade, exercised rather than read off the DDL.
      db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
      db.run('insert into Lapses (habit, day, amount) values (1, 9000, 1)');
      db.run('delete from Habits where id = 1');

      expect(db.queryInt('select count(*) from Lapses'), 0,
          reason: 'computed.schema#5 — a habit takes its lapses with it');
    });

    test('a day carries at most one row, and neither key may be missing', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);
      db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
      db.run('insert into Lapses (habit, day, amount) values (1, 9000, 1)');

      expect(
        () => db.run(
            'insert into Lapses (habit, day, amount) values (1, 9000, 7)'),
        throwsA(isA<SqliteException>().having((SqliteException e) => e.message,
            'message', contains('UNIQUE constraint failed'))),
        reason: 'computed.schema#6',
      );

      // SQLite lets a NULL sit in a PRIMARY KEY column of a rowid table — the
      // one place its constraint handling differs from every other engine — so
      // `not null` is written out on both key columns and has to be checked.
      expect(
        () => db.run(
            'insert into Lapses (habit, day, amount) values (1, null, 1)'),
        throwsA(isA<SqliteException>().having((SqliteException e) => e.message,
            'message', contains('NOT NULL constraint failed'))),
        reason: 'computed.schema#7',
      );
    });

    test('an existing database gains the journal empty', () {
      // Nothing in this build has ever written an abstinence habit, so there
      // is nothing to backfill: unlike 102, migration 103 carries no
      // `insert ... select`, and the proof is that the table arrives empty on
      // a file that already had habits and definitions in it.
      final Database db = openAppSchemaDatabaseAt(102);
      addTearDown(db.close);
      db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
      db.run("insert into HabitDefinitions (habit, kind, payload) "
          "values (1,'sleep','{}')");

      db.migrateTo(103, (int v) => migrationSqlFor(v) ?? '');

      expect(db.queryInt('select count(*) from Lapses'), 0,
          reason: 'computed.schema#4');
      expect(db.queryInt('select count(*) from HabitDefinitions'), 1,
          reason: 'computed.schema#4 — 103 does not disturb 102');
    });
  });
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/database/extension_migrations_test.dart
```

Ожидается FAIL с именем: `Expected: <103> Actual: <102>` на строке
`expect(appDatabaseVersion, 103, ...)`, и `SqliteException: no such table: Lapses`
в двух других тестах.

- [ ] **Шаг 3: написать миграцию**

В `extension_migrations.dart`, в карту `extensionMigrationSql`, после записи
`102:`:

```dart
  103: r"""
create table Lapses (
    habit integer not null references Habits(id) on delete cascade,
    day integer not null,
    amount integer not null,
    primary key (habit, day)
);""",
```

и заменить

```dart
const int appDatabaseVersion = 102;
```

на

```dart
const int appDatabaseVersion = 103;
```

Никакого `insert ... select`: в отличие от 102, проводить нечего — ни одна
отгруженная сборка не писала воздержание.

- [ ] **Шаг 4: запустить, увидеть, что падает старая проверка**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/database/extension_migrations_test.dart
```

Ожидается: группа `migration 103` — PASS; группа `migration 102` — FAIL,
`Expected: <102> Actual: <103>` на строке `expect(db.getVersion(), 102, reason:
'computed.schema#1');` — сегодня это `extension_migrations_test.dart:166`, а
после импорта, дописанного шагом 1, — `:167`. Это
единственное место во всём репозитории, где 102 прибито литералом (проверено
`grep -rn "getVersion(), 102"`); всё остальное считает от `appDatabaseVersion`.

- [ ] **Шаг 5: снять переуточнение в тесте 102**

Утверждение о версии в тесте 102 никогда не было про 102: оно означало «мы
доехали до этой миграции». Заменить в `extension_migrations_test.dart`,
в первом тесте группы `migration 102` (сегодня строка 166, после импорта
шага 1 — 167),

```dart
      expect(db.getVersion(), 102, reason: 'computed.schema#1');
```

на

```dart
      // Not an equality: this test is about what 102 creates, and pinning the
      // current version here would make every later migration break it.
      expect(db.getVersion(), greaterThanOrEqualTo(102),
          reason: 'computed.schema#1');
```

Запустить снова — весь файл PASS.

- [ ] **Шаг 6: файл со 102 доезжает до 103 и ничего не теряет**

Схема проверена в памяти. Не проверено главное: файл, уехавший на телефон со
102, открывается сборкой 103 через `AppDatabase.openAndMigrate` — то есть без
карантина `<path>.invalid` и без потери данных.

Создать `app/test/platform/upgrade_102_to_103_test.dart`. Обвязка — та же, что у
соседнего `app/test/platform/first_run_foreign_keys_test.dart`:
`TestWidgetsFlutterBinding.ensureInitialized()`, `late Directory tempDir` с
`createTempSync` в `setUp` и `deleteSync(recursive: true)` в `tearDown`; тест
живёт в приложении, а не в ядре, потому что предмет проверки —
`AppDatabase.openAndMigrate` и его карантин.

```dart
  test('a real file written by the shipped build opens and keeps everything',
      () {
    final String path = '${tempDir.path}/habits.db';
    // Файл ровно той сборки, что уже на телефоне: схема 102, привычка,
    // определение сна и запись дня.
    final Database old = Sqlite3Database.open(path);
    old.setVersion(8);
    old.migrateTo(102, (int v) => migrationSqlFor(v) ?? '');
    old.run("insert into Habits (id, name, uuid) values (1, 'Sleep', 'u1')");
    old.run("insert into HabitDefinitions (habit, kind, payload) "
        "values (1, 'sleep', '{}')");
    old.run('insert into Repetitions (habit, timestamp, value) '
        'values (1, 1451606400000, 500000)');
    old.close();

    final Database upgraded = AppDatabase.openAndMigrate(path);
    addTearDown(upgraded.close);

    expect(upgraded.getVersion(), 103, reason: 'computed.schema#4');
    expect(upgraded.queryInt('select count(*) from Habits'), 1,
        reason: 'computed.schema#4 — подъём версии не карантинит файл');
    expect(upgraded.queryInt('select count(*) from HabitDefinitions'), 1,
        reason: 'computed.schema#4');
    expect(upgraded.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.schema#4 — журнал приезжает пустым');
    expect(File('$path.invalid').existsSync(), isFalse,
        reason: 'computed.schema#4 — карантин есть цена отката, а не '
            'обновления');
  });
```

Мутация: ключ `103:` в карте → `104:` — файл доезжает до 103 без скрипта, и
`select count(*) from Lapses` бросает `no such table`.

Проверки каскада здесь нет намеренно: `openAppSchemaDatabase` держит его в
шаге 1 (это про DDL), настоящее соединение — Задача 19, а «после удаления не
остаётся ни строки ни в одной таблице» — Задача 23, и она строго сильнее.

- [ ] **Шаг 7: мутации**

Каждую вносить обратной текстовой заменой и такой же заменой возвращать; `git
checkout` не применять.

| Мутация | Что обязано упасть |
|---|---|
| `const int appDatabaseVersion = 103;` → `= 102;` | `computed.schema#4`: `Expected: <103> Actual: <102>`, плюс `no such table: Lapses` |
| `references Habits(id) on delete cascade` → `references Habits(id)` в 103 | `computed.schema#5`: `delete from Habits` бросит `FOREIGN KEY constraint failed` |
| `primary key (habit, day)` → `primary key (habit, day, amount)` | `computed.schema#6`: вторая вставка того же дня пройдёт, `throwsA` не сработает |
| `day integer not null` → `day integer` в 103 | `computed.schema#7`: вставка `null` пройдёт |
| ключ `103:` в карте → `104:` | `computed.schema#4`: версия доедет до 103 без скрипта, таблицы не будет |

- [ ] **Шаг 8: записать правила**

В `docs/extensions/COMPUTED.md`, в блок `computed.schema`, дописать пунктами
4–7:

```markdown
4. `computed.schema#4` Миграция 103 создаёт Lapses и ничего не проводит: версия сборки — 103.
5. `computed.schema#5` Колонка `habit` таблицы `Lapses` объявлена с `on delete cascade`, то есть удаление привычки уносит её срывы. Что после удаления не остаётся ни строки ни в одной таблице — сильнее и стоит отдельно (`computed.lifecycle#6`).
6. `computed.schema#6` У дня не больше одной строки срыва.
7. `computed.schema#7` Ни привычка, ни день строки не могут быть null.
```

- [ ] **Шаг 9: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add packages/uhabits_core app ../docs/extensions/COMPUTED.md
git commit -m "Add the lapse journal table"
```

---

### Task 2: допуск и единица в определении (1-schema.2)

**Файлы:**
- Создать: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_payload.dart`
- Изменить: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Тест: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/abstinence_payload_test.dart`

**Интерфейсы:**
- Потребляет: `HabitDefinition` (`computed/habit_definition.dart`), поле
  `payload`.
- Даёт:

```dart
const String abstinenceAllowanceKey = 'allowance';
const String abstinenceUnitKey = 'unit';
const String abstinenceUnitCount = 'count';
const String abstinenceUnitMinutes = 'minutes';
const double defaultAbstinenceAllowance = 0.0;

Map<String, Object?> abstinencePayload({
  double allowance = defaultAbstinenceAllowance,
  String unit = abstinenceUnitCount,
});
double abstinenceAllowanceOf(HabitDefinition definition);
String abstinenceUnitOf(HabitDefinition definition);
bool isAbstinenceLapse(HabitDefinition definition, num amount);
```

- [ ] **Шаг 1: написать падающий тест**

Создать `test/computed/abstinence_payload_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/abstinence_payload.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';

HabitDefinition withPayload(Map<String, Object?> payload) => HabitDefinition(
      kind: ComputedKind.abstinence,
      committedFrom: 9000,
      payload: payload,
    );

void main() {
  test('a bare commitment allows nothing, counted in occurrences', () {
    final HabitDefinition definition = withPayload(abstinencePayload());

    expect(abstinenceAllowanceOf(definition), 0.0,
        reason: 'computed.allowance#2');
    expect(abstinenceUnitOf(definition), abstinenceUnitCount,
        reason: 'computed.allowance#2');
    expect(isAbstinenceLapse(definition, 1), isTrue,
        reason: 'computed.allowance#2 — one tap is a lapse');
  });

  test('a lapse begins past the allowance, not at it', () {
    final HabitDefinition definition = withPayload(abstinencePayload(
        allowance: 30.0, unit: abstinenceUnitMinutes));

    expect(isAbstinenceLapse(definition, 29), isFalse,
        reason: 'computed.allowance#3');
    expect(isAbstinenceLapse(definition, 30), isFalse,
        reason: 'computed.allowance#3 — «не более допуска» keeps the promise');
    expect(isAbstinenceLapse(definition, 31), isTrue,
        reason: 'computed.allowance#3');
  });

  test('lowering the allowance re-judges days already recorded', () {
    // The whole reason the allowance is not frozen onto the row. The same
    // recorded amount is judged by whatever the commitment says now.
    final HabitDefinition lenient = withPayload(abstinencePayload(
        allowance: 30.0, unit: abstinenceUnitMinutes));
    final HabitDefinition strict = lenient.copyWith(
        payload: abstinencePayload(
            allowance: 10.0, unit: abstinenceUnitMinutes));

    expect(isAbstinenceLapse(lenient, 20), isFalse,
        reason: 'computed.allowance#1');
    expect(isAbstinenceLapse(strict, 20), isTrue,
        reason: 'computed.allowance#1 — the day is re-judged, not remembered');
  });

  test('a payload of a shape nobody knows reads as allowing nothing', () {
    // The payload is JSON some build wrote. A value of the wrong shape must
    // not take the habit down, and the safe side of a promise is the strict
    // one: allow nothing.
    for (final Object? junk in <Object?>[null, 'thirty', <int>[30], -5]) {
      final HabitDefinition definition = withPayload(<String, Object?>{
        abstinenceAllowanceKey: junk,
        abstinenceUnitKey: 7,
      });
      expect(abstinenceAllowanceOf(definition), 0.0,
          reason: 'computed.allowance#4');
      expect(abstinenceUnitOf(definition), abstinenceUnitCount,
          reason: 'computed.allowance#4');
    }
  });

  test('a whole number and a fraction read as the same kind of number', () {
    // jsonDecode gives back 30 for one build's payload and 30.0 for another's,
    // and half a glass is an allowance somebody will write. All three are law.
    for (final Object? written in <Object?>[30, 30.0]) {
      expect(
          abstinenceAllowanceOf(withPayload(<String, Object?>{
            abstinenceAllowanceKey: written,
            abstinenceUnitKey: abstinenceUnitMinutes,
          })),
          30.0,
          reason: 'computed.allowance#4');
    }
    expect(
        abstinenceAllowanceOf(withPayload(<String, Object?>{
          abstinenceAllowanceKey: 0.5,
          abstinenceUnitKey: abstinenceUnitCount,
        })),
        0.5,
        reason: 'computed.allowance#4 — «полбокала» есть допуск, а не «ни '
            'капли»');
  });

  test('an empty unit is written as the named default, not as an empty string',
      () {
    // The payload goes into the database, and a reader that takes
    // `payload['unit']` straight would get `''` where the rule promises
    // `count`. The helper is the only writer, so it is the place to settle it.
    expect(abstinencePayload(unit: '')[abstinenceUnitKey], abstinenceUnitCount,
        reason: 'computed.allowance#2');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/abstinence_payload_test.dart
```

Ожидается FAIL: `Error: Couldn't resolve the package 'uhabits_core' ... abstinence_payload.dart` —
файла нет.

- [ ] **Шаг 3: написать реализацию**

Создать `lib/src/computed/abstinence_payload.dart`:

```dart
/// Where an abstinence habit keeps its allowance, and in what.
///
/// The allowance belongs to the commitment, not to a day: it is set once in the
/// editor — "no more than 30 minutes" — and it applies to every day the
/// commitment covers, including days already recorded. Freezing it onto a lapse
/// row would leave a person who lowers their allowance with yesterday still
/// judged by the old one, and a person who raises it unable ever to forgive a
/// day already written. So the row carries the measured amount and this carries
/// the line it is measured against.
///
/// The unit is here for the same reason and one more: two rows in different
/// units are not comparable, so neither a sum nor a comparison with the
/// allowance would mean anything. It is named once.
library;

import 'habit_definition.dart';

/// Key under which the definition states how much one day may hold.
const String abstinenceAllowanceKey = 'allowance';

/// Key under which the definition states what it is all counted in.
const String abstinenceUnitKey = 'unit';

/// Counted in occurrences. With the default allowance of zero, any recorded
/// amount at all is a lapse — which is the "one tap" case.
const String abstinenceUnitCount = 'count';

/// Counted in minutes.
const String abstinenceUnitMinutes = 'minutes';

/// What a commitment allows until it says otherwise: nothing.
const double defaultAbstinenceAllowance = 0.0;

/// The payload of a commitment allowing [allowance] [unit]s a day.
///
/// `double`, not `int`: the editor's field is numeric with `decimal: true`,
/// `Habit.targetValue` is a `double`, and half a glass is an allowance somebody
/// will write. `LapseRepository.amount` — whole units — is a different quantity
/// in a different column.
///
/// An empty [unit] reads back as [abstinenceUnitCount] rather than being stored
/// as `''`: the unit is named once, and a caller that writes a bare
/// `unitController.text.trim()` would put in the database something other than
/// what `computed.allowance#2` promises.
Map<String, Object?> abstinencePayload({
  double allowance = defaultAbstinenceAllowance,
  String unit = abstinenceUnitCount,
}) =>
    <String, Object?>{
      abstinenceAllowanceKey: allowance,
      abstinenceUnitKey: unit.trim().isEmpty ? abstinenceUnitCount : unit,
    };

/// The allowance [definition] states, or [defaultAbstinenceAllowance] when it
/// states none, states a negative one, or states something that is not a
/// number.
///
/// Tolerant on purpose: the payload is JSON written by some build, and a value
/// of the wrong shape must not take the habit down. Falling back to zero is the
/// strict reading — every recorded amount is a lapse — which is the side to err
/// on for a promise.
double abstinenceAllowanceOf(HabitDefinition definition) {
  final Object? value = definition.payload[abstinenceAllowanceKey];
  if (value is! num) return defaultAbstinenceAllowance;
  final double allowance = value.toDouble();
  return allowance < 0 ? defaultAbstinenceAllowance : allowance;
}

/// The unit [definition] states, or [abstinenceUnitCount] when it states none.
String abstinenceUnitOf(HabitDefinition definition) {
  final Object? value = definition.payload[abstinenceUnitKey];
  return value is String && value.isNotEmpty ? value : abstinenceUnitCount;
}

/// Whether [amount], recorded for one day, breaks the promise [definition]
/// makes.
///
/// For the interface — the editor, its hints, anything that has to *say* where
/// a lapse begins. **Not** for scoring: the scoring loop lives in the ported
/// `ScoreList`, never sees a definition, and judges by
/// `normalizedRollingSum > targetValue`. There is exactly one judge, and it is
/// `Habit.targetValue`; this is the same comparison spelled for a reader
/// (`computed.allowance#1`, `computed.lapse-score#5`).
///
/// `>` and not `>=`: the condition is "no more than the allowance", so an
/// amount exactly equal to it is still keeping the promise.
bool isAbstinenceLapse(HabitDefinition definition, num amount) =>
    amount > abstinenceAllowanceOf(definition);
```

Дописать в `lib/uhabits_core.dart`, в блок `// Computed habits`:

```dart
export 'src/computed/abstinence_payload.dart';
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/
```
Ожидается PASS.

- [ ] **Шаг 5: мутации**

| Мутация | Что обязано упасть |
|---|---|
| `amount > abstinenceAllowanceOf(...)` → `amount >= ...` | `computed.allowance#3`: `isAbstinenceLapse(definition, 30)` даст `true` |
| `if (value is! num) return defaultAbstinenceAllowance;` → `if (value is! int) ...` | `computed.allowance#4`: `30.0` прочтётся как 0 |
| `final double allowance = value.toDouble();` → `value.toInt().toDouble()` | `computed.allowance#4`: `0.5` прочтётся как 0 — «полбокала» станет «ни капли» |
| `unit.trim().isEmpty ? abstinenceUnitCount : unit` → `unit` | `computed.allowance#2`: пустая единица уедет в базу пустой строкой |
| `return allowance < 0 ? defaultAbstinenceAllowance : allowance;` → `return allowance;` | `computed.allowance#4`: `-5` прочтётся как `-5`, и день с нулём станет срывом |
| `const double defaultAbstinenceAllowance = 0.0;` → `= 1.0;` | `computed.allowance#2`: один тап перестанет быть срывом |
| `value is String && value.isNotEmpty` → `value is String` | тест не упадёт — поэтому в наборе есть `abstinenceUnitKey: 7`, а пустую строку добавить в тот же цикл: `<String, Object?>{abstinenceUnitKey: ''}` обязан дать `abstinenceUnitCount` |

Пятую строку внести в тест сразу: в цикл шага 1 добавить проверку

```dart
    expect(abstinenceUnitOf(withPayload(<String, Object?>{
          abstinenceUnitKey: '',
        })), abstinenceUnitCount,
        reason: 'computed.allowance#4');
```

- [ ] **Шаг 6: записать правила**

В `docs/extensions/COMPUTED.md` добавить новый блок после `computed.schema`:

```markdown
- [x] `computed.allowance`
1. `computed.allowance#1` Допуск хранится в определении как запись обязательства и зеркалится в `Habit.targetValue`, по которому его читает оценка; обе записи ставит один `save()`. В строке срыва допуска нет: смена допуска переоценивает уже записанные дни.
2. `computed.allowance#2` По умолчанию допуск ноль, единица — счёт: один тап есть срыв.
3. `computed.allowance#3` Срыв начинается за допуском: величина, равная допуску, обещание не нарушает. `isAbstinenceLapse` есть эта формулировка для интерфейса; оценка судит тем же сравнением по `targetValue` (`computed.lapse-score#5`).
4. `computed.allowance#4` Payload неизвестной формы читается как допуск ноль и единица «счёт», а не роняет привычку.
```

- [ ] **Шаг 7: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add packages/uhabits_core ../docs/extensions/COMPUTED.md
git commit -m "Put an abstinence habit's allowance in its definition"
```

---

### Task 3: LapseRepository (1-schema.3)

**Файлы:**
- Создать: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_repository.dart`
- Изменить: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Тест: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_repository_test.dart`

**Интерфейсы:**
- Потребляет: `Database` и расширения `run/query/querySingle`
  (`database/database.dart`), таблицу `Lapses` из задачи 1-schema.1.
- Даёт:

```dart
class LapseRepository {
  LapseRepository(Database db);
  static const int minimumAmount = 1;
  int? forDay(int habitId, int day);
  Map<int, int> range(int habitId, int fromDay, int toDay);
  void save(int habitId, int day, {int amount = minimumAmount});
  void remove(int habitId, int day);
  int? firstDay(int habitId);
  int? lastDay(int habitId);
}
```

Проводка на `AppScope` **сюда не входит**: `AppScope.open` правят три задачи, и
порядок у них единственный (см. «Порядок исполнения»). Поле `lapses` вешается
Задачей 19, после того как Задача 11 подняла `late final AppScope scope`, а
Задача 17 перенесла объявление `definitions` выше цикла пересчёта.

- [ ] **Шаг 1: написать падающий тест**

Создать `test/computed/lapse_repository_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late LapseRepository repository;

  setUp(() {
    db = openAppSchemaDatabase();
    repository = LapseRepository(db);
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    db.run("insert into Habits (id, name, uuid) values (2, 'y', 'u2')");
  });

  tearDown(() => db.close());

  test('silence is the default, and it is spelled by no row at all', () {
    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#1');
    expect(repository.range(1, 8990, 9010), isEmpty,
        reason: 'computed.lapses#1');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.lapses#1 — a clean day writes nothing, not a zero');
  });

  test('a tap records one unit', () {
    repository.save(1, 9000);

    expect(repository.forDay(1, 9000), LapseRepository.minimumAmount,
        reason: 'computed.lapses#2');
  });

  test('a lapse of nothing is refused', () {
    // A zero would satisfy "no more than the allowance" at the default
    // allowance of zero: a row asserting nothing. Silence is the absent row.
    expect(() => repository.save(1, 9000, amount: 0),
        throwsA(isA<ArgumentError>()), reason: 'computed.lapses#2');
    expect(() => repository.save(1, 9000, amount: -3),
        throwsA(isA<ArgumentError>()), reason: 'computed.lapses#2');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.lapses#2 — and nothing is written on the way out');
  });

  test('recording the same day again replaces the amount', () {
    repository.save(1, 9000, amount: 20);
    repository.save(1, 9000, amount: 45);

    expect(repository.forDay(1, 9000), 45, reason: 'computed.lapses#3');
    expect(db.queryInt('select count(*) from Lapses'), 1,
        reason: 'computed.lapses#3 — replaced, not appended');
  });

  test('an amount below the allowance is still kept as it stands', () {
    // The journal records what happened; whether it is a lapse is the
    // definition's judgement and is made afresh every time it is asked.
    repository.save(1, 9000, amount: 20);

    expect(repository.forDay(1, 9000), 20, reason: 'computed.lapses#5');
  });

  test('taking a day back returns it to silence', () {
    repository.save(1, 9000);
    repository.remove(1, 9000);

    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#4');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.lapses#4');
    // A second tap on a clean day must not throw.
    repository.remove(1, 9000);
    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#4');
  });

  test('a range gives back the recorded days of that habit and no others', () {
    repository.save(1, 8999, amount: 3);
    repository.save(1, 9000, amount: 5);
    repository.save(1, 9002, amount: 7);
    repository.save(2, 9000, amount: 99);

    expect(repository.range(1, 9000, 9002), <int, int>{9000: 5, 9002: 7},
        reason: 'computed.lapses#5');
    expect(repository.range(2, 8999, 9002), <int, int>{9000: 99},
        reason: 'computed.lapses#5 — one habit does not see another\'s');
  });

  test('the ends of the journal come from the journal', () {
    expect(repository.firstDay(1), isNull, reason: 'computed.lapses#6');
    expect(repository.lastDay(1), isNull, reason: 'computed.lapses#6');

    repository.save(1, 9002);
    repository.save(1, 8990);
    repository.save(2, 12000);

    expect(repository.firstDay(1), 8990, reason: 'computed.lapses#6');
    expect(repository.lastDay(1), 9002, reason: 'computed.lapses#6');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_repository_test.dart
```
Ожидается FAIL: `Error: ... lapse_repository.dart ... doesn't exist`.

- [ ] **Шаг 3: написать репозиторий**

Создать `lib/src/computed/lapse_repository.dart`:

```dart
import '../database/database.dart';

/// The journal an abstinence habit is scored from.
///
/// A row says how much of the thing happened on a day, in the unit the habit's
/// definition names. Whether that amount is a lapse is deliberately not stored:
/// the allowance lives in the definition and can be changed afterwards, and a
/// judgement frozen into the row would keep yesterday's allowance for ever.
///
/// Silence is the default state and it is spelled by the absence of a row. A
/// stored zero would be a fact asserting nothing — at the default allowance of
/// zero it satisfies "no more than the allowance" — so [save] refuses it, in
/// the same spirit as a day with nothing to say staying absent for sleep.
///
/// Written the way `DefinitionRepository` is written: the schema is stated once,
/// here, and nothing outside prepares SQL against `Lapses`.
class LapseRepository {
  LapseRepository(this._db);

  final Database _db;

  /// The smallest amount a row may carry.
  ///
  /// One tap is one unit. Zero is not a smaller lapse; it is the absence of
  /// one, and the absence of one is the absence of the row.
  static const int minimumAmount = 1;

  /// How much happened on [day], or null when the journal is silent.
  int? forDay(int habitId, int day) => _db.querySingle<int>(
        'select amount from Lapses where habit = ? and day = ?',
        <String>['$habitId', '$day'],
        (stmt) => stmt.getInt(0),
      );

  /// The amounts recorded in `[fromDay, toDay]`, keyed by day.
  ///
  /// Days with nothing recorded are simply absent, exactly as in
  /// `SleepSessionRepository.range`: a missing day is not a day of zero, and
  /// inventing a zero here would make it one.
  Map<int, int> range(int habitId, int fromDay, int toDay) {
    final Map<int, int> result = <int, int>{};
    _db.query(
      'select day, amount from Lapses '
      'where habit = ? and day >= ? and day <= ? order by day',
      <String>['$habitId', '$fromDay', '$toDay'],
      (stmt) => result[stmt.getInt(0)] = stmt.getInt(1),
    );
    return result;
  }

  /// Records that [amount] happened on [day], replacing whatever was there.
  ///
  /// [amount] defaults to one because the ordinary gesture is a tap, which has
  /// no quantity of its own to give.
  void save(int habitId, int day, {int amount = minimumAmount}) {
    if (amount < minimumAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'a lapse of nothing is silence, and silence is the absent row',
      );
    }
    _db.run(
      'insert into Lapses (habit, day, amount) values (?, ?, ?) '
      'on conflict(habit, day) do update set amount = excluded.amount',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, day);
        stmt.bindInt(3, amount);
      },
    );
  }

  /// Takes [day] back out of the journal. Silent when nothing was there, which
  /// is what an undo tap on a clean day is.
  void remove(int habitId, int day) => _db.run(
        'delete from Lapses where habit = ? and day = ?',
        (stmt) {
          stmt.bindInt(1, habitId);
          stmt.bindInt(2, day);
        },
      );

  /// The earliest day with a row, or null when there is none.
  ///
  /// The recompute range of an abstinence habit cannot be taken from its
  /// entries — a habit that records nothing while it is being kept has no
  /// oldest entry — so the ends of the journal are asked of the journal.
  int? firstDay(int habitId) => _db.querySingle<int?>(
        'select min(day) from Lapses where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// The latest day with a row, or null when there is none.
  int? lastDay(int habitId) => _db.querySingle<int?>(
        'select max(day) from Lapses where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );
}
```

Дописать в `lib/uhabits_core.dart`, в блок `// Computed habits`:

```dart
export 'src/computed/lapse_repository.dart';
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/ test/database/
```
Ожидается PASS.

- [ ] **Шаг 5: мутации**

| Мутация | Что обязано упасть |
|---|---|
| убрать `if (amount < minimumAmount) { throw ... }` целиком | `computed.lapses#2`: `throwsA(isA<ArgumentError>())` не сработает |
| `on conflict(habit, day) do update set amount = excluded.amount` → `on conflict(habit, day) do nothing` | `computed.lapses#3`: `forDay` вернёт 20 вместо 45 |
| `where habit = ? and day >= ? and day <= ?` → `where day >= ? and day <= ?` | `computed.lapses#5`: диапазон привычки 2 вернёт четыре дня вместо одного |
| в `firstDay`: `select min(day) from Lapses` → `select max(day) from Lapses` | `computed.lapses#6`: `firstDay(1)` вернёт 9002 вместо 8990 |
| `delete from Lapses where habit = ? and day = ?` → `... where habit = ?` | тест `computed.lapses#4` пройдёт — поэтому в него добавить второй день: перед `remove` записать `repository.save(1, 8999)`, а после проверить `expect(repository.forDay(1, 8999), 1)` |

Пятую строку внести в тест сразу.

- [ ] **Шаг 6: записать правила**

В `docs/extensions/COMPUTED.md` добавить блок:

```markdown
- [x] `computed.lapses`
1. `computed.lapses#1` Молчание — состояние по умолчанию: чистый день не пишет ни строки, ни нуля.
2. `computed.lapses#2` Величина срыва не меньше единицы; ноль и отрицательное отвергаются, и ничего при этом не пишется.
3. `computed.lapses#3` Повторная запись того же дня заменяет величину, а не добавляет строку.
4. `computed.lapses#4` Снятие срыва удаляет только свой день и молчит на дне, которого нет.
5. `computed.lapses#5` Чтение диапазона отдаёт записанные величины как есть и только своей привычки.
6. `computed.lapses#6` Границы журнала берутся из журнала, а не из записей привычки.
```

- [ ] **Шаг 7: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add packages/uhabits_core ../docs/extensions/COMPUTED.md
git commit -m "Add the lapse journal repository"
```

---

### Task 4: сведение — отступление и полный прогон (1-schema.5)

**Файлы:**
- Изменить: `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`
- Изменить: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/CHANGELOG.md`

**Интерфейсы:** ничего не даёт коду; закрывает бухгалтерию слоя.

- [ ] **Шаг 1: записать отступление**

В `docs/parity/DEVIATIONS.md`, в раздел `## Расширения`, после записи
`### sleep: схема уходит выше версии 25`:

```markdown
### computed: журнал срывов поднимает схему до 103

Миграция 103 добавляет таблицу `Lapses`. Оригинал её не знает, и не знает её ни
одна отгруженная сборка порта: файл, побывавший в этой, несёт `user_version` 103,
`isKnownDatabaseVersion` отвергает его в сборке со 102, и `AppScope` уводит базу
в карантин `<path>.invalid`, открывая пустую.

Влияние на пользователя: откат на предыдущую сборку порта после первого запуска
этой невозможен — то же, что уже принято за 100 и 102. Копия, снятая до
обновления, остаётся читаемой.

Тип привычки при этом не расходится: воздержание хранится как обычная числовая
привычка, `habits.type` остаётся равным 1.
```

- [ ] **Шаг 2: проверить реестр**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
dart tool/parity_coverage.dart --verify
```
Ожидается exit 0. Каждое новое правило — `computed.schema#4…#7`,
`computed.allowance#1…#4`, `computed.lapses#1…#6` — процитировано ровно теми
тестами, что написаны выше; префикс `computed.` тест
`parity_coverage_test.dart:108` требует, и он соблюдён. Правил
`computed.backup#4` и `#5` здесь ещё нет: перенос журнала при восстановлении
копии — Задача 22, CSV-экспорт — Задача 42.

- [ ] **Шаг 3: полный прогон**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core && dart test
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test
```
Ожидается PASS без правок в паритетных наборах: `docs/parity/FEATURES.md` не
тронут ни строкой, `schema_extras_test.dart` и `migrations_early/late_test.dart`
ходят через `openMigratedDatabase`, который останавливается на схеме Kotlin и
таблицы 103 не видит.

- [ ] **Шаг 4: строка в CHANGELOG**

```markdown
- Журнал срывов: миграция 103, таблица `Lapses`, репозиторий.
```

- [ ] **Шаг 5: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add ../docs/parity/DEVIATIONS.md CHANGELOG.md
git commit -m "Record the lapse journal's schema bump as a deviation"
```

---

#### Чего в этой задаче нет

- **CSV-экспорта журнала.** Спецификация требует протянуть боковую таблицу во
  все три точки экспорта. Это работа не схемы, а экспорта, и она в плане есть —
  Задача 42. Копия — побайтовый файл — берёт `Lapses` даром уже сейчас.
- **Кто и когда пишет в журнал.** Тап по ячейке списка, редактор «не более 30
  минут» и снятие — двери, а `LapseRepository` есть замок. Двери вешают
  Задача 24 (`AbstinenceSync`, арифметика дня) и задачи раздела списка.
- **Сигнала инвалидации после записи в журнал.** Отступление
  «computed: инвалидация после записи дня осталась сонной» требует обобщить
  хук 4 при появлении второго жителя; это отдельный раздел, и `LapseRepository`
  намеренно не зовёт никакой `onChanged` — иначе форма сигнала была бы решена
  здесь, между делом.

## Раздел «Арифметика: срыв делит оценку пополам»


Раздел отвечает на три вопроса и ни на какие другие: чем именно является
значение дня привычки-воздержания, где в счёте оценки происходит деление
пополам, и почему это деление, а не обнуление и не затухание порта.

### Что уже даёт порт и что придётся добавить

`ScoreList.recompute` (`packages/uhabits_core/lib/src/models/score_list.dart:44-120`)
в числовой ветви at-most уже даёт даром ровно то, что нужно воздержанию:

* `previousValue` стартует с `1.0` — «невиновен, пока не доказано» (строка 69);
* молчание есть успех: `max(0, values[offset])` превращает `Entry.unknown`
  (`-1`) в нулевую сумму, и ветвь `targetValue <= 0` отдаёт
  `percentageCompleted = 1.0` (строки 73, 95);
* пропуск переносит оценку предыдущего дня и не считается ничем (строка 79);
* при `Frequency.daily` знаменатель равен 1, поэтому скользящее окно есть ровно
  один день: каждый день прибавляет себя и вычитает предыдущий, и
  `normalizedRollingSum` есть значение самого дня, делённое на 1000.

Не даёт порт одного — половины. **Это доказуемо, а не «неудобно»:** шаг порта
аффинный,

```
s' = s * multiplier + pct * (1 - multiplier),   multiplier = 0.5^(sqrt(freq)/13)
```

и при `pct ∈ [0, 1]` всегда `s' >= s * multiplier`. Для ежедневной привычки
`multiplier = 0.9480775143391714`, то есть один день не может опустить оценку
больше чем на 5.2% — какое бы значение дня мы ни записали и как бы ни
подобрали цель. Половина требует `multiplier <= 0.5`, то есть
`sqrt(freq)/13 >= 1`, то есть частоты 169 раз в день; при ней чистый день даёт
`(s + 1) / 2`, кольцо забывает всё за неделю и перестаёт быть оценкой
поведения. Значит: **либо арифметика вне аффинного шага, либо не половина.**
Владелец выбрал половину, поэтому цикл трогать придётся.

### Форма правки: поле, а не параметр и не подкласс

Три пути были рассмотрены, выбран третий.

1. **Подкласс `ScoreList` с переопределённым `recompute`** — не проходит:
   `models.model-factory#3` и `persistence.model-factory#5` закрыты тестами
   `expect(modelFactory.buildScoreList().runtimeType, ScoreList)`
   (`test/models/model_factory_test.dart:212,270`), а `Habit.scores` объявлено
   `final` и после сборки не подменяется.
2. **Новый именованный параметр `recompute`** — задевает
   `models.score-list-recompute-boolean#1`, который перечисляет сигнатуру
   дословно, и заставляет `Habit.recompute` (порт) знать про воздержание.
3. **Мутируемое поле на самом экземпляре `ScoreList`** — задевает наименьшее.
   Список scores и так один на привычку; сигнатура `recompute` остаётся
   дословно той, что записана в `models.score-list-recompute-boolean#1`;
   `Habit.recompute` не меняется ни на символ; фабрика по-прежнему отдаёт
   `runtimeType == ScoreList`. При выключенном поле цикл считает ровно то же,
   что Kotlin, — это проверяется прогоном всего портированного набора без
   единой правки.

### Значение дня привычки-воздержания

`amount * 1000`, где `amount` — суммарная величина срывов за день в единице
привычки (штуки при допуске 0, минуты при допуске «не более 30 минут»). Это не
доля и не проценты: у сна значение дня есть процент × 1000 потому, что у сна
измеряется процент, а у воздержания измеряется величина — то есть работает
обычная числовая конвенция оригинала, та же, что у любой at-most привычки.

Конвенция слоя «строго выше 3» соблюдается сама собой: минимальный срыв есть
1 и даёт 1000. День без срыва не пишется вовсе — `null`, а не ноль:
записанный ноль заморозил бы день навсегда (`computed.day-write#3`), а
отсутствующий день даёт `max(0, -1) = 0` и потому полный успех.

Допуск лежит в `Habit.targetValue` в тех же единицах, и сравнение ведётся в
них: срыв есть `normalizedRollingSum > targetValue`.

### Порядок задач

`2-score.1` — значение дня; `2-score.2` — деление в цикле и запись отклонения;
`2-score.3` — долгий счёт, тот самый, ради которого обнуление отвергнуто;
`2-score.4` — включатель `applyLapseScoring`; `2-score.5` — сквозная проверка
через `Habit.recompute()` и закрытие реестра.

### Task 5: значение дня привычки-воздержания (2-score.1)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_day_value.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_day_value_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`

**Interfaces:**
- Produces: `int? lapseDayValue(int amount)` — top-level функция в
  `lib/src/computed/lapse_day_value.dart`.
- Consumes: `Entry.skip` (`lib/src/models/entry.dart:8`), `DayWriter.write`
  (`lib/src/computed/day_writer.dart:23`) — журнал срывов будет звать
  `writer.write(habit, day, lapseDayValue(amount))`.

**Steps:**

1. Добавить в `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
   в конец файла новый блок правил. Флажок пока `- [ ]`: `parity_coverage
   --verify` требует, чтобы у закрытой фичи каждое правило было процитировано,
   а цитаты появятся к задаче 2-score.5.

```markdown
- [ ] `computed.lapse-score`
1. `computed.lapse-score#1` Молчание есть успех: день без записи даёт `percentageCompleted = 1.0`, и оценка растёт по формуле порта.
2. `computed.lapse-score#2` День срыва хранится как `amount * 1000` — обычная числовая конвенция, а не проценты сна; минимальный срыв есть 1 и даёт 1000, поэтому значение никогда не попадает на 1, 2 или 3. Дня без срыва не существует: `lapseDayValue` отдаёт null, а не ноль.
3. `computed.lapse-score#3` Срыв делит оценку пополам: `previousValue = previousValue / 2` вместо шага порта. Не 5% затухания порта и не обнуление.
4. `computed.lapse-score#4` Срыв есть факт, а не величина: любое превышение допуска делит ровно пополам — 45 минут при допуске 30 наказываются как 4500.
5. `computed.lapse-score#5` Срыв есть превышение допуска, и судья у него один на всю привычку: в оценке это `normalizedRollingSum > targetValue`, в интерфейсе — `isAbstinenceLapse(definition, величина)`, и это одно сравнение, названное дважды (`targetValue` есть зеркало допуска, `computed.allowance#1`). При допуске 0 срывом становится любая запись; при допуске 30 — только величина больше тридцати, и так же её рисует ячейка (`computed.abstinence-cell#2`).
6. `computed.lapse-score#6` Деление включает поле `ScoreList.halvesOnLapse`; по умолчанию оно выключено, и тогда оценка совпадает с портом до последнего бита.
7. `computed.lapse-score#7` Деление действует только для at-most: на at-least привычке включённое поле не меняет ничего.
8. `computed.lapse-score#8` Пропуск не есть срыв: `Entry.skip` переносит оценку предыдущего дня, как в порте.
9. `computed.lapse-score#9` Срыв раз в две недели держит кольцо на 2/3 в конце цикла и ниже половины 6 дней из 14; обнуление держало бы 1/2 и ниже половины 13 дней из 14. Срыв раз в три недели держит 0.792086.
10. `computed.lapse-score#10` Тринадцать чистых дней после срыва с 1.0 возвращают ровно 0.75; затухание порта на том же срыве дало бы 0.974039, что от идеального месяца на кольце не отличить.
11. `computed.lapse-score#11` `applyLapseScoring` включает деление ровно для вида `abstinence` и выключает его для любого другого вида и для отсутствия определения.
12. `computed.lapse-score#12` Поле переживает `Habit.recompute()`: привычка-воздержание, пересчитанная обычным путём, даёт делённую оценку, а её сосед без определения — портовую.
```

2. Написать падающий тест
   `packages/uhabits_core/test/computed/lapse_day_value_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_day_value.dart';
import 'package:uhabits_core/src/models/entry.dart';

void main() {
  test('a lapse day is the amount times one thousand', () {
    expect(lapseDayValue(1), 1000, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(45), 45000, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(4500), 4500000, reason: 'computed.lapse-score#2');
  });

  test('the smallest lapse still clears the sentinels', () {
    // 1, 2 и 3 значат yesAuto, yesManual и skip. Минимальный срыв есть 1 и
    // даёт 1000 — попасть на сигнальное значение нечем.
    expect(lapseDayValue(1)!, greaterThan(Entry.skip),
        reason: 'computed.lapse-score#2');
  });

  test('a day without a lapse is nothing at all, not a zero', () {
    // Записанный ноль замораживает день навсегда; отсутствующий день даёт
    // max(0, -1) = 0 и потому полный успех.
    expect(lapseDayValue(0), isNull, reason: 'computed.lapse-score#2');
    expect(lapseDayValue(-3), isNull, reason: 'computed.lapse-score#2');
  });
}
```

3. Запустить и увидеть названный отказ:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_day_value_test.dart
```

   Ожидаемый отказ: `Error: Error when reading
   'lib/src/computed/lapse_day_value.dart': No such file or directory`.

4. Написать
   `packages/uhabits_core/lib/src/computed/lapse_day_value.dart`, а следом
   дописать строку в `packages/uhabits_core/lib/uhabits_core.dart`, в блок
   `// Computed habits`:

```dart
export 'src/computed/lapse_day_value.dart';
```

   Без неё функция не видна ни `AppScope`, ни UI: приложение импортирует ядро
   как `package:uhabits_core/uhabits_core.dart as core`, и `src`-путь оттуда
   закрыт.

   Сам файл:

```dart
import '../models/entry.dart';

/// Значение дня привычки-воздержания.
///
/// Не доля и не проценты. У сна значение дня есть процент × 1000, потому что у
/// сна измеряется процент; у воздержания измеряется величина — сколько именно
/// сорвался, — поэтому работает обычная числовая конвенция оригинала
/// `amount * 1000`, та же, что у любой at-most привычки. Допуск лежит в
/// `Habit.targetValue` в тех же единицах, и сравнение «сорвался ли» ведётся в
/// них же.
///
/// Возвращает null, когда за день срывов не было: день остаётся
/// отсутствующим. Ноль писать нельзя — он замораживает день навсегда, поздние
/// данные его уже не вылечат (`computed.day-write#3`), — а отсутствующий день
/// и так даёт `max(0, -1) = 0` и полный успех.
int? lapseDayValue(int amount) {
  if (amount <= 0) return null;
  final int value = amount * 1000;
  assert(
    value > Entry.skip,
    'a lapse day value must never land on yesAuto, yesManual or skip',
  );
  return value;
}
```

5. Запустить снова — зелено:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_day_value_test.dart
```

6. Мутация, подтверждающая различающую силу. Заменить в
   `lib/src/computed/lapse_day_value.dart` `final int value = amount * 1000;`
   на `final int value = amount * 100;` — падает первый тест:
   `Expected: <1000> Actual: <100>`. Вернуть обратной текстовой заменой
   `amount * 100` → `amount * 1000` (не `git checkout`).
   Вторая мутация: заменить `if (amount <= 0) return null;` на
   `if (amount < 0) return null;` — падает третий тест: `Expected: null
   Actual: <0>`. Вернуть обратной заменой `amount < 0` → `amount <= 0`.

7. Коммит: `computed: значение дня привычки-воздержания`.

---

### Task 6: деление пополам в цикле оценки (2-score.2)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/models/score_list.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_score_test.dart` (create)
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`

**Interfaces:**
- Produces: `bool ScoreList.halvesOnLapse` — мутируемое поле экземпляра,
  по умолчанию `false`.
- Consumes: `ScoreList.recompute({required Frequency frequency, required bool
  isNumerical, required NumericalHabitType numericalHabitType, required double
  targetValue, required List<Entry> Function(LocalDate, LocalDate)
  computedEntries, required LocalDate from, required LocalDate to})` —
  сигнатура не меняется ни на символ.

**Steps:**

1. Создать `packages/uhabits_core/test/computed/lapse_score_test.dart` с
   приспособлением и первыми шестью тестами:

```dart
import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Множитель порта для ежедневной привычки, выписанный независимо от Score.
final double m = pow(0.5, sqrt(1.0) / 13.0).toDouble();

/// Тот же обход, что у `EntryList.getByInterval`: по одной записи на каждый
/// день из [from, to], новейший первым, UNKNOWN за день без записи.
class FakeEntries {
  final Map<LocalDate, Entry> _byDate = <LocalDate, Entry>{};

  void put(LocalDate date, int value) => _byDate[date] = Entry(date, value);

  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    final List<Entry> result = <Entry>[];
    if (from.isNewerThan(to)) return result;
    LocalDate current = to;
    while (!current.isOlderThan(from)) {
      result.add(_byDate[current] ?? Entry(current, Entry.unknown));
      current = current.minus(1);
    }
    return result;
  }
}

void main() {
  late LocalDate today;
  late FakeEntries entries;
  late ScoreList scores;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = FakeEntries();
    scores = ScoreList();
  });

  tearDown(resetToday);

  void reset() {
    entries = FakeEntries();
    scores = ScoreList();
  }

  /// Пересчёт по диапазону [today - days, today]. Нижняя граница задаётся
  /// явно: у воздержания она есть день обязательства, а не первая запись, —
  /// и это отдельная работа, от которой арифметика не зависит.
  void recompute({
    required int days,
    double targetValue = 0.0,
    bool halvesOnLapse = true,
    NumericalHabitType targetType = NumericalHabitType.atMost,
  }) {
    scores.halvesOnLapse = halvesOnLapse;
    scores.recompute(
      frequency: Frequency.daily,
      isNumerical: true,
      numericalHabitType: targetType,
      targetValue: targetValue,
      computedEntries: entries.getByInterval,
      from: today.minus(days),
      to: today,
    );
  }

  void lapse(int offset, {int amount = 1}) =>
      entries.put(today.minus(offset), amount * 1000);

  test('silence is success', () {
    // Ни одной записи: max(0, -1) даёт нулевую сумму, ветвь допуска 0 отдаёт
    // 1.0, и оценка стоит на 1.0 — подтверждать нечего.
    recompute(days: 3);
    expect(scores[today].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#1');
    expect(scores[today.minus(3)].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#1');
  });

  test('a lapse halves the score', () {
    lapse(0);
    recompute(days: 5);
    expect(scores[today.minus(1)].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#3');
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#3');
    // Ни затухание порта, ни ноль.
    expect((scores[today].value - m).abs(), greaterThan(0.4),
        reason: 'computed.lapse-score#3 — не 5% порта');
    expect(scores[today].value, greaterThan(0.4),
        reason: 'computed.lapse-score#3 — не обнуление');
  });

  test('a lapse is a fact, not an amount', () {
    // Допуск 30 минут. Сорок пять минут и семьдесят пять часов — один и тот
    // же срыв: «срыв есть факт, но с допуском».
    lapse(0, amount: 45);
    recompute(days: 5, targetValue: 30.0);
    final double afterSmall = scores[today].value;

    reset();
    lapse(0, amount: 4500);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(afterSmall, 1e-12),
        reason: 'computed.lapse-score#4');
    expect(afterSmall, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#4');
  });

  test('the tolerance decides where a lapse begins', () {
    lapse(0, amount: 20);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#5');

    reset();
    lapse(0, amount: 31);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#5');

    // При допуске 0 срывом становится любая запись: один тап.
    reset();
    lapse(0);
    recompute(days: 5);
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#5');
  });

  test('with the flag off the port is bit-identical', () {
    // Набор правила models.score-list-recompute-numerical-at-most#5: 1000 за
    // двадцать дней до сегодня и 5000 в каждый из двадцати последних дней при
    // цели 2.0.
    for (int i = 0; i < 20; i++) {
      lapse(i, amount: 5);
    }
    lapse(20, amount: 1);
    recompute(days: 21, targetValue: 2.0, halvesOnLapse: false);
    expect(scores[today].value, closeTo(0.344253, 1e-6),
        reason: 'computed.lapse-score#6');
    expect(scores[today.minus(20)].value, closeTo(1.0, 1e-9),
        reason: 'computed.lapse-score#6');
    expect(scores[today.minus(1)].value, closeTo(0.363106, 1e-6),
        reason: 'computed.lapse-score#6');
  });

  test('the halving is an at-most rule only', () {
    // Цель 2.0 при 3000 в день: сумма превышает цель каждый день. Без охраны
    // `isAtMost` включённое поле делило бы пополам и здесь.
    for (int i = 0; i < 20; i++) {
      lapse(i, amount: 3);
    }
    recompute(
      days: 20,
      targetValue: 2.0,
      targetType: NumericalHabitType.atLeast,
    );
    expect(scores[today].value, closeTo(0.655747, 1e-6),
        reason: 'computed.lapse-score#7');
  });

  test('a skip is not a lapse', () {
    lapse(2);
    entries.put(today.minus(1), Entry.skip);
    recompute(days: 5);
    expect(scores[today.minus(2)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#8');
    // Пропуск переносит оценку срыва, а не делит её ещё раз, хотя его
    // собственная тройка и попадает в скользящую сумму.
    expect(scores[today.minus(1)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#8');
    expect(scores[today].value, closeTo(0.525961, 1e-6),
        reason: 'computed.lapse-score#8');
  });
}
```

2. Запустить и увидеть названный отказ:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_score_test.dart
```

   Ожидаемый отказ — ошибка компиляции: `Error: The setter 'halvesOnLapse'
   isn't defined for the class 'ScoreList'.`

3. Добавить поле в `lib/src/models/score_list.dart`. Точная вставка — сразу
   после строки 14 (`final Map<LocalDate, Score> _map = {};`):

```dart
  /// Делить ли оценку пополам в день срыва вместо шага порта.
  ///
  /// Расширение слоя вычисляемых привычек, а не порт. Ни один портированный
  /// путь этого поля не пишет: `ModelFactory.buildScoreList()` отдаёт список с
  /// выключенным полем, и при выключенном поле [recompute] считает ровно то
  /// же, что Kotlin, — весь портированный набор проходит без правки. Ставит
  /// его `applyLapseScoring` (`computed/lapse_scoring.dart`), читает — ветвь
  /// at-most ниже.
  ///
  /// Правила: `docs/extensions/COMPUTED.md` `computed.lapse-score`.
  /// Отклонение: `docs/parity/DEVIATIONS.md`, запись «computed: срыв делит
  /// оценку пополам мимо формулы порта».
  bool halvesOnLapse = false;
```

4. Заменить шаг оценки в числовой ветви. Тот же текст присваивания стоит и в
   булевой ветви, поэтому якорь берётся с контекстом. Заменить

```dart
          }

          previousValue =
              Score.compute(freq, previousValue, percentageCompleted);
        }
      } else {
```

   на

```dart
          }

          // Срыв делит оценку пополам. Шагом порта половину не выразить: он
          // аффинный, previousValue * multiplier + pct * (1 - multiplier), и
          // при multiplier 0.948078 один день не может опустить оценку больше
          // чем на 5.2% — ни при каком значении дня и ни при какой цели.
          if (halvesOnLapse && isAtMost && normalizedRollingSum > targetValue) {
            previousValue = previousValue / 2;
          } else {
            previousValue =
                Score.compute(freq, previousValue, percentageCompleted);
          }
        }
      } else {
```

5. Запустить новый набор — зелено:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_score_test.dart
```

6. Доказать, что порт не сдвинулся, — прогнать портированные наборы, которые
   гоняют этот цикл, без единой правки в них:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/models/score_list_test.dart test/models/score_test.dart \
  test/models/habit_test.dart test/models/frequency_test.dart \
  test/models/model_factory_test.dart test/models/streak_list_test.dart
```

   Затем весь набор целиком: `dart test`.

7. Мутации, по одной, с возвратом обратной текстовой заменой:
   - `previousValue = previousValue / 2;` → `previousValue = 0.0;` — падает
     «a lapse halves the score»: `Expected: a numeric value within <0.4> of
     <...>` на проверке «не обнуление», и `Expected: <0.5> Actual: <0.0>`.
     Вернуть заменой `previousValue = 0.0;` → `previousValue = previousValue / 2;`.
   - `normalizedRollingSum > targetValue` → `normalizedRollingSum >= targetValue`
     — падает «silence is success»: молчаливый день с суммой 0 и допуском 0
     начинает делиться, `Expected: <1.0> Actual: <0.0625>`. Вернуть заменой
     `>= targetValue` → `> targetValue`.
   - `normalizedRollingSum > targetValue` → `normalizedRollingSum > 0` —
     падает «the tolerance decides where a lapse begins»: двадцать минут при
     допуске тридцать делятся, `Expected: <1.0> Actual: <0.5>`. Вернуть заменой
     `normalizedRollingSum > 0` → `normalizedRollingSum > targetValue`.
   - убрать `isAtMost &&` из условия — падает «the halving is an at-most rule
     only»: `Expected: <0.655747> Actual: <0.0>`. Вернуть заменой
     `if (halvesOnLapse && normalizedRollingSum` →
     `if (halvesOnLapse && isAtMost && normalizedRollingSum`.
   - убрать `halvesOnLapse &&` — падает «with the flag off the port is
     bit-identical»: `Expected: <0.344253> Actual: <9.5e-7>`. Вернуть заменой.
   - вынести ветвь наружу из-под `if (values[offset] != Entry.skip)` — падает
     «a skip is not a lapse»: тройка пропуска даёт сумму 0.003 > 0,
     `Expected: <0.5> Actual: <0.25>`. Вернуть переносом обратно внутрь.
   - `previousValue = previousValue / 2;` →
     `previousValue = Score.compute(freq, previousValue, percentageCompleted) / 2;`
     — падает «a lapse is a fact, not an amount»: 45 минут дают 0.487020, а
     4500 — 0.474039. Вернуть обратной заменой.

8. Записать отклонение в `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`
   — новым разделом рядом с прочими записями `### computed: …`:

```markdown
### computed: срыв делит оценку пополам мимо формулы порта

**Каких правил касается:** `models.score-list-recompute-numerical-at-most#2`,
`models.score-list-recompute-numerical-at-most#3`,
`models.score-list-recompute-numerical-at-least#8`. Сигнатуры
`models.score-list-recompute-boolean#1` правка не касается: добавлено поле, а
не параметр.

**Что в оригинале:** в числовой ветви `ScoreList.recompute` день всегда двигает
оценку одним и тем же аффинным шагом
`previousValue * multiplier + percentageCompleted * (1 - multiplier)`, где
`multiplier = 0.5^(sqrt(freq)/13)`. Для ежедневной привычки это 0.948078: один
день не может опустить оценку больше чем на 5.2%.

**Что делаем:** у `ScoreList` появляется поле `bool halvesOnLapse = false`.
Когда оно включено и привычка есть at-most, день, чья нормированная скользящая
сумма превысила цель, ставит `previousValue = previousValue / 2` вместо шага
порта. Все прочие дни, включая пропуски, идут прежним путём.

**Почему нельзя было обойтись портом:** половина недостижима арифметически.
Шаг порта отдаёт `s' >= s * multiplier` при любом `pct` из [0, 1]; чтобы
получить `s / 2`, нужен `multiplier <= 0.5`, то есть `sqrt(freq)/13 >= 1`, то
есть частота 169 раз в день. При ней чистый день даёт `(s + 1) / 2`, кольцо
забывает всё за неделю и перестаёт быть оценкой поведения. Значит либо
арифметика вне аффинного шага, либо не половина.

**Почему именно поле, а не параметр и не подкласс:** подкласс закрыт правилами
`models.model-factory#3` и `persistence.model-factory#5` — оба закреплены
тестами `expect(modelFactory.buildScoreList().runtimeType, ScoreList)`, — и
`Habit.scores` объявлено `final`. Новый параметр `recompute` переписал бы
сигнатуру из `models.score-list-recompute-boolean#1` и заставил бы
`Habit.recompute` знать про воздержание. Поле не делает ни того, ни другого.

**Почему именно половина, а не ноль и не затухание порта:** решение владельца
от 2026-08-26. Срыв раз в две недели: с делением кольцо стоит на 2/3 в конце
цикла и ниже половины 6 дней из 14; с обнулением — на 1/2 и ниже половины 13
дней из 14, то есть практически всегда, и шкала перестаёт что-либо различать;
с затуханием порта — на 0.9506, что от идеального месяца на кольце не отличить.
Числа закреплены тестом `computed.lapse-score#9`.

**Влияние на пользователя:** none для привычек оригинала. Поле выключено
везде, кроме воздержания; портированный набор проходит без единой правки —
это и есть проверка.

**Дата:** 2026-08-27
```

9. Коммит: `computed: срыв делит оценку пополам`.

---

### Task 7: долгий счёт — почему пополам, а не в ноль (2-score.3)

Задача целиком про то, ради чего решение и принято: доказать числами, что
обнуление паркует кольцо ниже половины навсегда, а деление — нет.

**Files:**
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_score_test.dart` (modify)

**Interfaces:**
- Consumes: `ScoreList.halvesOnLapse`, `Score.compute(double frequency, double
  previousScore, double checkmarkValue)`.
- Produces: ничего нового в коде.

**Steps:**

1. Дописать в `test/computed/lapse_score_test.dart`, внутрь `main()`, два
   теста:

```dart
  test('a lapse every two weeks parks the ring at two thirds, not below half',
      () {
    // Четыреста циклов по четырнадцать дней: срыв, затем тринадцать чистых.
    // Сегодня есть последний день цикла, срыв — в offset 13.
    const int cycles = 400;
    const int period = 14;
    for (int c = 0; c < cycles; c++) {
      lapse(13 + c * period);
    }
    recompute(days: cycles * period);

    expect(scores[today.minus(13)].value, closeTo(1 / 3, 1e-9),
        reason: 'computed.lapse-score#9');
    expect(scores[today].value, closeTo(2 / 3, 1e-9),
        reason: 'computed.lapse-score#9');

    int belowHalf = 0;
    for (int d = 0; d < period; d++) {
      if (scores[today.minus(d)].value < 0.5) belowHalf++;
    }
    expect(belowHalf, 6, reason: 'computed.lapse-score#9');

    // Почему не обнуление — тот же цикл, посчитанный здесь же и независимо.
    // Оно даёт равновесие ровно 1/2 и держит кольцо ниже половины тринадцать
    // дней из четырнадцати: шкала перестаёт что-либо различать.
    double zeroed = 1.0;
    for (int c = 0; c < cycles; c++) {
      zeroed = 0.0;
      for (int d = 0; d < period - 1; d++) {
        zeroed = Score.compute(1.0, zeroed, 1.0);
      }
    }
    // Контрольная величина отвергнутого варианта: кода фичи не касается.
    expect(zeroed, closeTo(0.5, 1e-9));

    int zeroedBelowHalf = 0;
    double v = 0.0;
    for (int d = 0; d < period; d++) {
      if (v < 0.5) zeroedBelowHalf++;
      v = Score.compute(1.0, v, 1.0);
    }
    // Контрольная величина отвергнутого варианта: кода фичи не касается.
    expect(zeroedBelowHalf, 13);

    // Срыв раз в три недели — 0.792086, тоже уверенно выше половины.
    reset();
    const int longPeriod = 21;
    for (int c = 0; c < 300; c++) {
      lapse(20 + c * longPeriod);
    }
    recompute(days: 300 * longPeriod);
    expect(scores[today].value, closeTo(0.792086, 1e-6),
        reason: 'computed.lapse-score#9');
  });

  test('thirteen clean days after a lapse return exactly three quarters', () {
    lapse(13);
    recompute(days: 20);
    expect(scores[today.minus(13)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#10');
    // m^13 = 0.5 по построению множителя, поэтому 1 - 0.5 * m^13 = 0.75 точно.
    expect(scores[today].value, closeTo(0.75, 1e-9),
        reason: 'computed.lapse-score#10');

    // А теперь затухание порта на том же самом срыве, посчитанное независимо:
    // 0.974039 против идеальной единицы. Разницы на кольце не видно — ради
    // этого 5% и отвергнуты.
    double decayed = Score.compute(1.0, 1.0, 0.0);
    for (int d = 0; d < 13; d++) {
      decayed = Score.compute(1.0, decayed, 1.0);
    }
    // Контрольная величина отвергнутого варианта: кода фичи не касается.
    // Обе цифры считаются здесь же из портированного `Score.compute`, поэтому
    // цитаты правила на них нет — правило держат те `expect`, что читают
    // `scores[...]`.
    expect(decayed, closeTo(0.974039, 1e-6));
    expect(1.0 - decayed, lessThan(0.03));
  });
```

2. Запустить:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_score_test.dart
```

   Оба теста обязаны пройти сразу — кода они не добавляют, они измеряют
   написанный в 2-score.2. Если они падают, значит ветвь деления написана
   неверно, и чинится она, а не ожидания.

3. Мутации:
   - `previousValue = previousValue / 2;` → `previousValue = 0.0;` — падает
     первый тест: `Expected: <0.6666666666666666> Actual: <0.5>`, а счётчик
     `belowHalf` становится 13 вместо 6. Это ровно то поведение, которое
     владелец отверг, и тест — его протокол. Вернуть обратной заменой.
   - `previousValue = previousValue / 2;` →
     `previousValue = previousValue * 0.75;` — падает первый тест:
     `Expected: <0.6666666666666666> Actual: <0.8...>`; падает и второй:
     `Expected: <0.75> Actual: <0.875>`. Вернуть обратной заменой.
   - удалить ветвь целиком (оставить только шаг порта) — падает первый тест:
     `Expected: <0.6666666666666666> Actual: <0.950640>`, то есть ровно то
     «5% на кольце не видно», о котором говорит спека. Вернуть обратной
     заменой.

4. Коммит: `computed: закреплено, почему пополам, а не в ноль`.

---

### Task 8: включатель `applyLapseScoring` (2-score.4)

Поле само себя не включит. Включатель нужен отдельной функцией, а не строчкой
на месте вызова, потому что мест будет больше одного (загрузка привычки,
сохранение определения, восстановление копии), и правило, размазанное по ним,
есть правило, которое донесут не во все.

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_scoring.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_scoring_test.dart`

**Interfaces:**
- Produces: `bool applyLapseScoring(Habit habit, HabitDefinition? definition)`
  — top-level функция в `lib/src/computed/lapse_scoring.dart`; ставит
  `habit.scores.halvesOnLapse` в обе стороны и возвращает поставленное.
- Consumes: `HabitDefinition.kind` (`lib/src/computed/habit_definition.dart:38`),
  `ComputedKind.abstinence` (там же, строка 9),
  `DefinitionRepository.forHabit(int habitId)`
  (`lib/src/computed/definition_repository.dart:16`) — у вызывающей стороны.

**Steps:**

1. Написать падающий тест
   `packages/uhabits_core/test/computed/lapse_scoring_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_scoring.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';

void main() {
  late Habit habit;

  setUp(() => habit = MemoryModelFactory().buildHabit()..id = 1);

  test('abstinence halves, and says so', () {
    expect(
      applyLapseScoring(
        habit,
        const HabitDefinition(kind: ComputedKind.abstinence),
      ),
      isTrue,
      reason: 'computed.lapse-score#11',
    );
    expect(habit.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11');
  });

  test('no other kind halves', () {
    applyLapseScoring(habit, const HabitDefinition(kind: ComputedKind.sleep));
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });

  test('a habit with no definition does not halve', () {
    applyLapseScoring(habit, null);
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });

  test('the switch works in both directions', () {
    // Объект привычки переживает и снятие определения, и смену вида.
    // Включатель, умеющий только включаться, оставил бы бывшее воздержание с
    // чужой арифметикой до перезапуска.
    applyLapseScoring(
      habit,
      const HabitDefinition(kind: ComputedKind.abstinence),
    );
    applyLapseScoring(habit, null);
    expect(habit.scores.halvesOnLapse, isFalse,
        reason: 'computed.lapse-score#11');
  });
}
```

2. Запустить и увидеть названный отказ:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_scoring_test.dart
```

   Ожидаемый отказ: `Error: Error when reading
   'lib/src/computed/lapse_scoring.dart': No such file or directory`.

3. Написать `packages/uhabits_core/lib/src/computed/lapse_scoring.dart` и
   дописать строку в `packages/uhabits_core/lib/uhabits_core.dart`, в блок
   `// Computed habits`:

```dart
export 'src/computed/lapse_scoring.dart';
```

   Без неё включатель не виден ни `attachDefinition`, ни `AppScope`. Сам файл:

```dart
import '../models/habit.dart';
import 'habit_definition.dart';

/// Включает деление оценки пополам ровно для привычек-воздержаний и
/// выключает его для всех прочих.
///
/// Ставит поле в обе стороны намеренно. Объект привычки живёт дольше своего
/// определения: определение можно снять, вид — сменить, а список привычек
/// пересобирается не при каждом чтении. Включатель, умеющий только
/// включаться, оставил бы бывшее воздержание с чужой арифметикой до
/// перезапуска.
///
/// Зовётся всюду, где привычка обретает своё определение: при загрузке
/// списка, при сохранении определения и при восстановлении копии. Возвращает
/// поставленное, чтобы вызывающему было что проверить.
bool applyLapseScoring(Habit habit, HabitDefinition? definition) {
  final bool halves = definition?.kind == ComputedKind.abstinence;
  habit.scores.halvesOnLapse = halves;
  return halves;
}
```

4. Запустить снова — зелено.

5. Мутации:
   - `definition?.kind == ComputedKind.abstinence` → `definition != null` —
     падает «no other kind halves»: `Expected: <false> Actual: <true>`.
     Вернуть обратной заменой.
   - тело на `if (definition?.kind == ComputedKind.abstinence) {
     habit.scores.halvesOnLapse = true; } return habit.scores.halvesOnLapse;`
     — падает «the switch works in both directions»: `Expected: <false>
     Actual: <true>`. Вернуть обратной заменой.

6. Коммит: `computed: включатель деления пополам`.

---

### Task 9: сквозная проверка через `Habit.recompute()` и закрытие реестра (2-score.5)

**Files:**
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/lapse_score_test.dart` (modify)
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`

**Interfaces:**
- Consumes: `Habit.recompute()` (`lib/src/models/habit.dart:128`),
  `applyLapseScoring`, `lapseDayValue`.
- Produces: ничего нового в коде; закрывает фичу `computed.lapse-score`.

**Steps:**

1. Дописать в `test/computed/lapse_score_test.dart` импорты

```dart
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_day_value.dart';
import 'package:uhabits_core/src/computed/lapse_scoring.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
```

   и тест — внутрь `main()`:

```dart
  test('the halving survives Habit.recompute()', () {
    Habit buildAbstinenceShapedHabit() =>
        MemoryModelFactory().buildHabit()
          ..type = HabitType.numerical
          ..targetType = NumericalHabitType.atMost
          ..targetValue = 0.0
          ..frequency = Frequency.daily;

    final Habit committed = buildAbstinenceShapedHabit()..id = 1;
    applyLapseScoring(
      committed,
      const HabitDefinition(kind: ComputedKind.abstinence, committedFrom: 5450),
    );
    committed.originalEntries
        .add(Entry(today.minus(5), lapseDayValue(1)!));
    committed.recompute();

    expect(committed.scores[today.minus(5)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#12');
    expect(committed.scores[today].value, closeTo(0.617008, 1e-6),
        reason: 'computed.lapse-score#12');

    // Сосед без определения на тех же самых данных считается портом: тот же
    // день теряет 5.2%, а не половину.
    final Habit plain = buildAbstinenceShapedHabit()..id = 2;
    applyLapseScoring(plain, null);
    plain.originalEntries.add(Entry(today.minus(5), lapseDayValue(1)!));
    plain.recompute();

    expect(plain.scores[today.minus(5)].value, closeTo(m, 1e-12),
        reason: 'computed.lapse-score#12');
    expect(plain.scores[today].value, closeTo(0.960228, 1e-6),
        reason: 'computed.lapse-score#12');
  });
```

   Замечание для исполнителя: `Habit.recompute()` берёт нижнюю границу от
   первой записи, а верхнюю — от `today.plus(30)`. Здесь запись есть, поэтому
   диапазон корректен и без дня обязательства; `committedFrom` в этом тесте
   стоит только затем, чтобы определение было настоящим. Нижняя граница по
   дню обязательства — работа другого раздела, и на арифметику она не влияет.

2. Запустить:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/lapse_score_test.dart test/computed/lapse_scoring_test.dart \
  test/computed/lapse_day_value_test.dart
```

3. Мутация: в `lib/src/computed/lapse_scoring.dart` заменить
   `habit.scores.halvesOnLapse = halves;` на `habit.scores.halvesOnLapse = false;`
   — падает сквозной тест: `Expected: <0.5> Actual: <0.948078>`. Вернуть
   обратной заменой. Вторая мутация: в `lib/src/models/score_list.dart`
   заменить `_map.clear();` на `// _map.clear();` — сквозной тест остаётся
   зелёным, а падает портированный `models.score-list-access#3`; это
   напоминание, что поле не должно менять форму пересчёта, и после проверки
   возвращается обратной заменой.

4. Закрыть фичу в `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`:
   заменить `- [ ] \`computed.lapse-score\`` на `- [x] \`computed.lapse-score\``.

5. Проверить реестр:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
dart tool/parity_coverage.dart --verify
```

   Ожидание: выход 0. Если инструмент называет непроцитированное правило —
   значит тест на него не написан, и пишется тест, а не правится правило.

6. Прогнать весь набор ядра целиком:

```
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test
```

7. Коммит: `computed: арифметика воздержания закрыта тестами`.

---

### Что этот раздел НЕ делает

* Не заводит таблицу `Lapses` и не пишет в неё — это другой раздел; отсюда он
  берёт `lapseDayValue(amount)` и `DayWriter.write`.
* Не трогает нижнюю границу пересчёта: день обязательства нужен сериям и
  счётчику «дней без срыва», а деление пополам от него не зависит.
* Не трогает `StreakList`: молчание, не считающееся успехом для серий, —
  отдельная работа с отдельным правилом.
* Не трогает ячейку списка и `cellIntensityOf`: `maxStoredValue` есть потолок
  процентов сна, а значение дня воздержания есть величина и может его
  превышать (200 минут дают 200000). Раскраска ячейки решается в разделе
  списка.
* Не зовёт `applyLapseScoring` ни из одного места приложения: его зовёт
  `attachDefinition` (Задача 17) — та же дверь, которой привычка обретает своё
  определение. Здесь функция только появляется и проверяется юнит-тестом; что
  фича **включена**, доказывает тест проводки в Задаче 17
  (`computed.lapse-score#11` процитировано обоими).

## Раздел «Подключение к слою: хуки и обобщение инвалидации»


Восемь хуков жизненного цикла из спецификации уже существуют — но в трёх формах:
kind-blind (работают для любого вида даром), sleep-shaped (названы по сну и знают
только его) и отсутствующие (у воздержания нет аналога). Разбор по хукам:

| Хук | Сегодня | Что делает эта секция |
|---|---|---|
| 1. Архив | `_syncSleepHabits` фильтрует `isArchived`, перечисляя по `SleepGoals` | `AppScope.computedHabits(kind)` — перечисление по определению, фильтр в одном месте (**6-hooks.1**) |
| 2. Удаление | `ComputedHabitHooks` уже kind-blind: снимает будильник любой удалённой/архивированной привычки | переименование поля под второй вид + тест, что воздержание накрыто (**6-hooks.4**) |
| 3. Восстановление копии | `DefinitionImporter` переносит определение; журнала срывов нет | `LapseImporter` по образцу `SleepImporter` (**6-hooks.5**) |
| 4. Инвалидация | `onSleepDataChanged`, зовётся руками из трёх мест сна | `onComputedDataChanged` + объявление внутри двери записи (**6-hooks.2**, **6-hooks.3**) |
| 5. Заметки | `DayWriter.write` уже хранит заметку — kind-blind | тест на воздержании (**6-hooks.4**) |
| 6. Пути записи | `WidgetBehavior.isComputed`, попапы, очередь тапов — все на `definitions.isComputed`, kind-blind | тест на воздержании + закрепление «воздержание числовое» (**6-hooks.4**) |
| 7. `onRandomize` | `ShowHabitMenuPresenter._isComputed` — kind-blind | тест на воздержании (**6-hooks.4**) |
| 8. Смена вида | задокументирована как невозможная, текст назван по сну | текст делается видонезависимым + механическая проверка «обратного хода нет» (**6-hooks.7**) |

Отдельно: **6-hooks.6** — «после удаления не остаётся ничего», на настоящем файле базы.

Порядок обязателен: 6-hooks.2 перед 6-hooks.3 (переименование, потом перенос
объявления в дверь), 6-hooks.1 перед 6-hooks.4 (тесты воздержания используют
`computedHabits`). 6-hooks.5 и 6-hooks.6 требуют таблицы `Lapses` (миграция 103) и
`LapseRepository` из секции журнала срывов.

### Task 10: сигнал инвалидации перестаёт быть сонным (6-hooks.2)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/sleep/sleep_section.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/edit_habit_model.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/sleep_freshness_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_freshness_test.dart` (create)

**Interfaces:**
- Produces: `void AppScope.onComputedDataChanged(int habitId)` — ровно та же
  подпись и то же тело, что у снятого `onSleepDataChanged`.
- Removes: `void AppScope.onSleepDataChanged(int habitId)`.

Это первая половина того, что требует запись отклонения «computed: инвалидация
после записи дня осталась сонной». Половина механическая — имя; вторая половина
(6-hooks.3) переносит объявление внутрь двери записи. Разделены, потому что
переименование трогает шесть мест и ни одного поведения, а перенос трогает одно
место и всё поведение; смешать их значит не понять, что именно сломалось.

**Шаги:**

1. Написать падающий тест. Создать
   `app/test/state/computed_freshness_test.dart`:

```dart
/// `computed.freshness` — что рассказывают остальному приложению, когда день
/// вычисляемой привычки записан.
///
/// Вычисленное значение не едет на команде: его не выбирают, а считают, и
/// отменять нечего. Но перерисовывается всё именно по команде — список держит
/// свою копию каждой галочки и каждого балла, виджеты публикуются из того же
/// сигнала. Канал один, и он не назван по виду: второй вид пишет из своих
/// мест, и ни одно из них не имело бы повода вспомнить про сонное имя.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ignore_for_file: implementation_imports

class RecordingCacheListener extends HabitCardListCacheListener {
  int changes = 0;

  @override
  void onItemChanged(int position) => changes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;
  late RecordingCacheListener listener;

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
    listener = RecordingCacheListener();
  });

  tearDown(() {
    scope.close();
    resetToday();
  });

  Habit computedHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'No smoking'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      ),
    );
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;
    return habit;
  }

  test('the channel is not named after a kind', () {
    final Habit habit = computedHabit();

    scope.onComputedDataChanged(habit.id!);

    expect(listener.changes, greaterThan(0),
        reason: 'computed.freshness#1 — a write nothing is told about is a '
            'row that goes on showing what it showed before');
  });

  test('a closed scope announces nothing', () {
    final Habit habit = computedHabit();
    scope.close();
    listener.changes = 0;

    scope.onComputedDataChanged(habit.id!);

    expect(listener.changes, 0,
        reason: 'computed.freshness#1 — refreshing a cache whose database is '
            'gone is a crash, not a redraw');
  });
}
```

2. Запустить:
   `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/state/computed_freshness_test.dart`
   → `Error: The method 'onComputedDataChanged' isn't defined for the type 'AppScope'.`

3. Переименовать объявление в `app/lib/state/app_scope.dart` вместе с докой —
   она названа по сну от первого до последнего слова. Доккомментарий начинается
   на `app_scope.dart:151` (`/// Announces that a sleep habit's stored values
   changed.`), сама сигнатура — на `:163`:

```dart
  /// Announces that a computed habit's stored values changed.
  ///
  /// A computed day does not travel on a Command: the value is worked out
  /// rather than chosen, so there is nothing to undo and no command to carry
  /// it. But everything that shows those values refreshes on a command — the
  /// habit list holds its own copy of every checkmark and score, and the
  /// home-screen widgets are republished from the same signal. Without this
  /// the list keeps showing the value it had before the write, and re-entering
  /// the screen does not help.
  ///
  /// Not named after a kind. The first kind's writes called this by hand from
  /// three places of its own; the second kind writes from three places of its
  /// own too, and none of them would have had any reason to remember a method
  /// called `onSleepDataChanged`. One name for the whole layer, and — see
  /// [DayWriter] — a door that calls it without being asked.
  void onComputedDataChanged(int habitId) {
    if (_closed) return;
    cache.refreshHabit(habitId);
    unawaited(_started?.sync.updateWidgets(habitId) ?? Future<void>.value());
  }
```

4. Обратным текстовым заменом (не `git checkout`) поправить пять оставшихся мест:
   - `app/lib/state/app_scope.dart:222`, в `_syncSleepHabits`. Там стоит `id`, а
     не `habit.id!` — цикл идёт по `sleepRepository.sleepHabitIds()`, и
     переменной `habit` в этой строке нет:
     `onSleepDataChanged(id);` → `onComputedDataChanged(id);`
   - `app/lib/ui/habits/sleep/sleep_section.dart:220`:
     `scope.onSleepDataChanged(habit.id!);` → `scope.onComputedDataChanged(habit.id!);`
   - `app/lib/state/edit_habit_model.dart:439`:
     `scope.onSleepDataChanged(saved.id!);` → `scope.onComputedDataChanged(saved.id!);`
   - `app/test/state/sleep_freshness_test.dart:149` и `:159`:
     `scope.onSleepDataChanged(habit.id!);` → `scope.onComputedDataChanged(habit.id!);`

   Проверить, что не осталось ни одного:
   `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && grep -rn "onSleepDataChanged" --include="*.dart" .`
   → пусто.

5. Прогнать:
   `cd .../app && flutter test test/state/computed_freshness_test.dart test/state/sleep_freshness_test.dart`
   → зелено.

6. Завести блок правил в `docs/extensions/COMPUTED.md`, после блока
   `computed.write-paths`:

```
- [ ] `computed.freshness`
1. `computed.freshness#1` Запись дня объявляется списку и виджетам одним каналом, общим для всех видов и не названным ни по одному из них.
2. `computed.freshness#2` Пачка дней объявляется один раз, а не по дню.
3. `computed.freshness#3` Не изменилось ничего — не объявляется ничего.
4. `computed.freshness#4` Привычка пересчитывается до объявления, а не после.
```

   Блок помечен `- [ ]`: `#2`…`#4` закрываются следующей задачей, и до этого
   `--verify` о них не спрашивает.

7. Коммит: `hooks: rename the invalidation signal off sleep`.

**Мутации:**
- вернуть в `onComputedDataChanged` ранний `return;` без проверки `_closed`
  (то есть убрать `if (_closed) return;`) → падает «a closed scope announces
  nothing» с исключением «database has already been closed»;
- убрать `cache.refreshHabit(habitId);` → падает «the channel is not named after
  a kind» (`changes` остаётся 0).

---

### Task 11: объявление переезжает внутрь двери записи (6-hooks.3)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/day_writer.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_sync.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/day_writer_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_freshness_test.dart`
- Delete (фрагмент): `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`

**Interfaces:**
- Produces: `typedef ComputedDataChanged = void Function(int habitId);`
- Produces: `const DayWriter({ComputedDataChanged? onChanged})`
- Produces: `bool DayWriter.writeDays(Habit habit, Map<int, int?> valuesByDay)`
- Produces: `bool DayWriter.clear(Habit habit, int day)` — снимает вычисленное
  значение, возвращая день в молчание (`computed.day-write#8`).
- Produces: `SleepSync({required SleepSessionRepository repository, required SleepDataSource source, TimeZone Function()? timeZone, DayWriter writer = const DayWriter()})`
- Consumes: `AppScope.onComputedDataChanged` из 6-hooks.2.
- Unchanged: `bool DayWriter.write(Habit habit, int day, int? storedValue)` — она
  и дальше ничего не объявляет; на ней висят `computed.day-write#1`…`#6`.

Запись отклонения говорит: «Общая дверь записи, `DayWriter.write`, возвращает
`bool changed`, но этот ответ читает только `SleepSync.recomputeDays`… дальше он
никуда не идёт». Здесь он идёт дальше. Дверь получает слушателя и второй метод —
пачечный, — который после последней записи пересчитывает привычку и объявляет об
изменении **один раз**. Почему один и почему в конце: сигнал запускает задачу
обновления строки списка, и первый свод за две недели иначе запустил бы
четырнадцать задач, каждая из которых читала бы недописанную пачку.

**Шаги:**

1. Написать падающие тесты ядра. Дописать в конец `main()` файла
   `packages/uhabits_core/test/computed/day_writer_test.dart`:

```dart
  group('a run of days', () {
    late List<int> announced;

    setUp(() {
      setToday(LocalDate(9000));
      announced = <int>[];
    });

    tearDown(resetToday);

    DayWriter announcingWriter() =>
        DayWriter(onChanged: (int id) => announced.add(id));

    test('is announced once, not once per day', () {
      final bool changed = announcingWriter().writeDays(habit, <int, int?>{
        8998: 40000,
        8999: 50000,
        9000: 60000,
      });

      expect(changed, isTrue, reason: 'computed.freshness#2');
      expect(announced, <int>[1], reason: 'computed.freshness#2');
    });

    test('announces nothing when nothing changed', () {
      announcingWriter().writeDays(habit, <int, int?>{9000: null});

      expect(announced, isEmpty, reason: 'computed.freshness#3');
    });

    test('recomputes before it announces', () {
      // What is told redraws from the habit, and on a test dispatcher it
      // redraws on this very stack. `computedEntries` is empty until
      // `recompute()` fills it, so reading it inside the callback is reading
      // the order the two happen in.
      int? seen;
      DayWriter(onChanged: (_) {
        seen = habit.computedEntries.get(LocalDate(9000)).value;
      }).writeDays(habit, <int, int?>{9000: 60000});

      expect(seen, 60000, reason: 'computed.freshness#4');
    });
  });

  group('taking a computed day back', () {
    setUp(() => setToday(LocalDate(9000)));
    tearDown(resetToday);

    test('returns the day to silence and keeps the note', () {
      // Без этой двери отмена срыва невозможна: `write(habit, day, null)`
      // означает «сказать нечего» и оставляет вчерашние 45000 лежать в дне,
      // который человек только что отменил. У `EntryList` удаления отдельного
      // дня нет — только `add` и `clear`.
      habit.originalEntries
          .add(Entry(LocalDate(9000), 45000, notes: 'третий день'));

      expect(const DayWriter().clear(habit, 9000), isTrue,
          reason: 'computed.day-write#8');
      expect(habit.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
          reason: 'computed.day-write#8');
      expect(habit.originalEntries.get(LocalDate(9000)).notes, 'третий день',
          reason: 'computed.day-write#8 — заметка человека остаётся');
    });

    test('does not take a skip off', () {
      habit.originalEntries.add(Entry(LocalDate(9000), Entry.skip));

      expect(const DayWriter().clear(habit, 9000), isFalse,
          reason: 'computed.day-write#8');
      expect(habit.originalEntries.get(LocalDate(9000)).value, Entry.skip,
          reason: 'computed.day-write#8 — пропуск есть отметка человека '
              '(`computed.day-write#4`)');
    });

    test('a day that was already silent is not written again', () {
      expect(const DayWriter().clear(habit, 9000), isFalse,
          reason: 'computed.day-write#8');
    });

    test('announces the same way a write does, once and after the recompute',
        () {
      habit.originalEntries.add(Entry(LocalDate(9000), 45000));
      habit.recompute();
      final List<int> announced = <int>[];

      DayWriter(onChanged: announced.add).clear(habit, 9000);

      expect(announced, <int>[1], reason: 'computed.freshness#2');
      expect(habit.computedEntries.get(LocalDate(9000)).value, Entry.unknown,
          reason: 'computed.freshness#4 — объявлять день, которого ещё не '
              'пересчитали, значит объявлять прежнее значение');
    });
  });
```

   Новых импортов не нужно ни одного: `setToday`, `resetToday` и `getToday`
   живут в `packages/uhabits_core/lib/src/time/local_date.dart` (строки 11–21),
   а `import 'package:uhabits_core/src/time/local_date.dart';` в этом файле уже
   стоит — им же приезжает `LocalDate`. Импорт `date_utils.dart` сюда не
   добавлять.

2. Запустить:
   `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core && dart test test/computed/day_writer_test.dart`
   → `Error: No named parameter with the name 'onChanged'.` и
   `Error: The method 'writeDays' isn't defined for the class 'DayWriter'.`

3. Расширить `packages/uhabits_core/lib/src/computed/day_writer.dart`. Заголовок
   класса и конструктор:

```dart
/// Told that a computed habit's stored days changed.
///
/// A function rather than the application scope: the door needs the
/// announcement, not the app. Core cannot see the app anyway.
typedef ComputedDataChanged = void Function(int habitId);
```

   и внутри класса, вместо `const DayWriter();`:

```dart
  const DayWriter({ComputedDataChanged? onChanged}) : _onChanged = onChanged;

  /// Null wherever there is nothing to tell — every test of the rules above,
  /// and every read-only use.
  final ComputedDataChanged? _onChanged;
```

   и новый метод после `write`:

```dart
  /// Writes a run of days, and — if any of them changed — recomputes the habit
  /// and announces it, once.
  ///
  /// The announcement is here rather than at each kind's sweep because a kind's
  /// sweep is exactly where a rule kept by convention gets dropped: the first
  /// kind called the signal by hand from three places of its own, and the
  /// second kind's three places would have had no reason to know it existed.
  ///
  /// Once, and after the last write, for two reasons that pull the same way.
  /// The signal starts a refresh task per call, and a first sync covering two
  /// years would start seven hundred of them. And a listener redraws from the
  /// habit — on the test dispatcher it redraws on this very stack — so it must
  /// not be told while the run is half written.
  ///
  /// `recompute()` before the announcement, and inside the door rather than at
  /// the caller, for the same reason the writes are here: a kind that forgot it
  /// would announce values nothing had recomputed
  /// (`computed.freshness#2`, `#3`, `#4`).
  bool writeDays(Habit habit, Map<int, int?> valuesByDay) {
    var changed = false;
    for (final MapEntry<int, int?> day in valuesByDay.entries) {
      if (write(habit, day.key, day.value)) changed = true;
    }
    if (!changed) return false;
    habit.recompute();
    _onChanged?.call(habit.id!);
    return true;
  }

  /// Снимает вычисленное значение с [day], возвращая день в молчание.
  ///
  /// Дверь наружу для отмены: `write(habit, day, null)` означает «сказать
  /// нечего» и оставляет запись как была (`computed.day-write#3`), а здесь
  /// сказано именно «того, что было записано, не было». Пишет `Entry.unknown`,
  /// а не удаляет строку: удаления отдельного дня у `EntryList` нет, а
  /// `-1` — то самое значение, которое сам оригинал пишет при выключении
  /// ячейки (`models/entry.dart:66-78`).
  ///
  /// Пропуск не снимает: он есть отметка человека (`computed.day-write#4`).
  ///
  /// Пересчёт и объявление — здесь же и в том же порядке, что у [writeDays]:
  /// отмена меняет балл и счётчик ровно так же, как запись, и звать
  /// объявление снаружи значило бы завести второе место, где живёт одно
  /// правило (`computed.freshness#2`, `#4`).
  bool clear(Habit habit, int day) {
    final LocalDate date = LocalDate(day);
    final Entry existing = habit.originalEntries.get(date);
    if (existing.value == Entry.skip) return false;
    if (existing.value == Entry.unknown) return false;
    habit.originalEntries
        .add(Entry(date, Entry.unknown, notes: existing.notes));
    habit.recompute();
    _onChanged?.call(habit.id!);
    return true;
  }
```

**Постановление:** `clear` заканчивается `recompute()` и объявлением, хотя
критика полноты приводила его тело без этих двух строк. Иначе отмена срыва не
перерисовывала бы ни список, ни виджеты — и мутация «собрать `AbstinenceSync` с
молчащим `DayWriter`» перестала бы что-либо ронять, то есть правило
`computed.freshness#4` для второго вида держалось бы честным словом. Дверь либо
владеет объявлением целиком, либо не владеет им вовсе.

4. Запустить тесты ядра — зелено. Заодно
   `dart test test/computed/ test/sleep/` — старые `computed.day-write#1..6`
   идут через `write` и не задеты.

5. Перевести сон на пачечную дверь. В
   `packages/uhabits_core/lib/src/sleep/sleep_sync.dart` конструктор:

```dart
  SleepSync({
    required this.repository,
    required this.source,
    TimeZone Function()? timeZone,
    this.writer = const DayWriter(),
  }) : _timeZone = timeZone ?? (() => DateUtils.currentTimeZone);

  final SleepSessionRepository repository;
  final SleepDataSource source;

  /// The one door a computed day goes through, and — when the application
  /// built it — the thing that tells the list and the widgets about it. The
  /// default writes and says nothing, which is what every core test wants.
  final DayWriter writer;
```

   и хвост `recomputeDays`: заменить

```dart
    final Map<int, SleepEpisode> nights =
        repository.range(habit.id!, fromDay, toDay);
    var wrote = false;
    for (final MapEntry<int, SleepEpisode> night in nights.entries) {
      final SleepBreakdown? breakdown = scoreNight(
        night.value,
        goal,
        offsets[night.key] ?? goal.homeUtcOffsetMinutes,
      );
      if (breakdown == null) continue;
      // A day the person marked as not applicable stays that way, even
      // though a night is on record for it — `DayWriter` owns that rule now,
      // along with keeping the note and never overwriting with the same
      // value. Scoring over the mark would quietly erase the judgement they
      // made about their own week — and would do it on the next sync after
      // the trip, nowhere near the moment they marked it.
      if (const DayWriter().write(habit, night.key, breakdown.storedValue)) {
        wrote = true;
      }
    }
    if (wrote) habit.recompute();
```

   на

```dart
    final Map<int, SleepEpisode> nights =
        repository.range(habit.id!, fromDay, toDay);
    // Scored first, written second. `DayWriter` owns the rules the write has
    // to keep — a day the person marked as not applicable stays that way even
    // though a night is on record for it, the note survives, an unchanged
    // value is not rewritten — and, since the run is handed over whole, it
    // also owns the recompute and the one announcement that follow it.
    final Map<int, int?> scored = <int, int?>{};
    for (final MapEntry<int, SleepEpisode> night in nights.entries) {
      final SleepBreakdown? breakdown = scoreNight(
        night.value,
        goal,
        offsets[night.key] ?? goal.homeUtcOffsetMinutes,
      );
      if (breakdown == null) continue;
      scored[night.key] = breakdown.storedValue;
    }
    writer.writeDays(habit, scored);
```

6. Снять теперь уже двойное объявление из свода. В
   `app/lib/state/app_scope.dart`, в `_syncSleepHabits`, удалить строку

```dart
      onComputedDataChanged(id);
```

   (это строка `app_scope.dart:222`, переименованная Задачей 10; аргумент там —
   `id`, а не `habit.id!`)

   Она объявляла безусловно — в том числе когда свод ничего не записал; теперь
   объявляет дверь, и только когда есть о чём.

7. Собрать дверь с сигналом в `AppScope.open`. Заменить хвост метода:

```dart
    final sleepRepository = SleepSessionRepository(
      database,
      () => DateTime.now().millisecondsSinceEpoch,
    );
    final definitions = DefinitionRepository(database);
    // The announcement is handed to the door that writes days rather than left
    // for each kind to remember. It has to close over the scope, which does
    // not exist until the next statement — hence `late`, and hence a callback
    // rather than the scope itself.
    late final AppScope scope;
    scope = AppScope._(
      sleepRepository: sleepRepository,
      definitions: definitions,
      sleepSync: SleepSync(
        repository: sleepRepository,
        // The resolved one, not the parameter: a bare StandardLogging writes
        // to a stdout that nothing on a phone reads, and these lines are the
        // only account of why Health went quiet. They belong in the buffer the
        // bug report carries.
        source: sleepSource ?? defaultSleepDataSource(logging: resolvedLogging),
        writer: DayWriter(
          onChanged: (int habitId) => scope.onComputedDataChanged(habitId),
        ),
      ),
      database: database,
      databasePath: databasePath,
      modelFactory: modelFactory,
      habitList: habitList,
      preferences: preferences,
      preferencesStorage: storage,
      taskRunner: taskRunner,
      commandRunner: commandRunner,
      midnightTimer: midnightTimer,
      logging: resolvedLogging,
      cache: cache,
      adapter: adapter,
    );
    return scope;
```

8. Экспортировать дверь из бочки, чтобы у второго вида она была видна без
   `src`-пути. В `packages/uhabits_core/lib/uhabits_core.dart`, рядом со строкой
   `export 'src/computed/definition_repository.dart';`, добавить:

```dart
export 'src/computed/day_writer.dart';
```

9. Дописать в `app/test/state/computed_freshness_test.dart` тест проводки — что
   объявляет именно дверь, и один раз на весь свод:

```dart
  test('a sweep announces once for the whole run, and only through the door',
      () async {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1390, wakeMinutes: 400));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;

    // Three nights land in one sweep. One announcement, not three — and not
    // four, which is what a hand-written call in the loop would add.
    for (final int day in <int>[8998, 8999, 9000]) {
      scope.sleepRepository.upsert(
        habit.id!,
        day,
        SleepEpisode(
          bedStartMillis: (day + 10956) * 86400000 + 23 * 3600000,
          wakeEndMillis: (day + 10957) * 86400000 + 7 * 3600000,
          asleepMinutes: 460,
          utcOffsetMinutes: 0,
        ),
        manual: true,
      );
    }
    scope.sleepSync.recomputeDays(habit, 8998, 9000);

    expect(listener.changes, 1, reason: 'computed.freshness#2');
  });
```

   Тесту нужен фиксированный часовой пояс: в `setUp` добавить
   `DateUtils.setFixedTimeZone(const FixedTimeZone(0));`, в `tearDown` —
   `DateUtils.setFixedTimeZone(null);`.

10. Прогнать всё, что могло сдвинуться:
    `cd .../packages/uhabits_core && dart test`
    `cd .../app && flutter test test/state/ test/ui/habits/sleep/`

11. **Удалить запись отклонения.** В `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`
    вырезать блок целиком — от строки

```
### computed: инвалидация после записи дня осталась сонной
```

    до строки

```
жителя: его записи не перерисуют ни список, ни виджеты, пока сигнал не станет
общим — и это первое, что надо сделать при его подключении.
```

    включительно, вместе с пустой строкой после неё. Соседи — `### sleep: утренний
    вопрос не проходит через машинерию напоминаний` сверху и `### computed: вид
    привычки после создания не меняется` снизу — должны остаться разделены ровно
    одной пустой строкой. Отклонения больше нет: сигнал общий, зовётся дверью, и
    у него четыре правила в реестре.

12. Дописать правило в `docs/extensions/COMPUTED.md`, в блок
    `computed.day-write`:

```markdown
8. `computed.day-write#8` Вычисленное значение можно снять: день возвращается в молчание, заметка человека остаётся, пропуск не снимается.
```

    и пометить блок `computed.freshness` закрытым:
    `- [ ]` → `- [x]`, после чего прогнать
    `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && dart tool/parity_coverage.dart --verify`.

13. Коммит: `hooks: the write door announces, once per run`.

**Мутации:**
- перенести `_onChanged?.call(habit.id!);` выше `habit.recompute();` → падает
  «recomputes before it announces» (`seen` = `Entry.unknown`, то есть −1);
- убрать `if (!changed) return false;` → падает «announces nothing when nothing
  changed»;
- перенести `_onChanged?.call(...)` внутрь цикла → падает «is announced once,
  not once per day» (`announced` = `[1, 1, 1]`) и «a sweep announces once»
  (`changes` = 3);
- вернуть `onComputedDataChanged(habit.id!)` в цикл `_syncSleepHabits` → падает
  «a sweep announces once» — но только если вызывать `syncSleepHabits`; поэтому
  сторожем этой конкретной мутации служит тест из 6-hooks.1
  (`sleep_sync_wiring_test.dart`), плюс `grep`-проверка шага 4 задачи 6-hooks.2;
- вернуть `writer.writeDays(...)` к старому циклу с `const DayWriter().write` →
  падает «a sweep announces once» (`changes` = 0);
- снять `if (existing.value == Entry.skip) return false;` в `clear` → падает
  «does not take a skip off»;
- в `clear` писать `0` вместо `Entry.unknown` → падает «returns the day to
  silence and keeps the note»: записанный ноль замораживает день навсегда, и
  поздние данные его уже не вылечат (`computed.day-write#3`);
- убрать `habit.recompute();` из `clear` → падает «announces the same way a
  write does».

---

## Раздел «Дата обязательства и текущая серия»


Три названных спекой разрыва, все три — в портированном коде ядра:

1. `models/streak_list.dart:21-28` — наружу торчит только `getBest(limit)`,
   отсортированный по длине. Текущей серии из него не достать: после
   `getBest` внутренний список ещё и переупорядочен (`_list.setRange`), так что
   «первая» серия — не самая новая.
2. `models/streak_list.dart:55` — фильтр at-most явно исключает `UNKNOWN`
   (`value != Entry.unknown && ...`), поэтому у привычки без записей серий нет
   вовсе. Для воздержания это ровно наоборот: молчание и есть успех.
3. `models/habit.dart:135-138` — нижняя граница окна пересчёта есть
   `entries.last.date`, то есть первая запись. Сорока чистых дней до первого
   срыва не существует, и серия начинается со срыва.

**Схема не трогается.** `committed_from` уже есть в `HabitDefinitions`
(миграция 102). Миграция 103 (`Lapses`) принадлежит другой секции; здесь она не
нужна и не упоминается.

**Что портированное меняется и чем это оплачивается:**

| Файл | Правка | Паритет | Чем закрывается |
|---|---|---|---|
| `models/streak_list.dart` | новый метод `getCurrent(day)` | добавление, ни одно правило `models.streak-*` не меняет поведения | `computed.streak#3` + запись в DEVIATIONS |
| `models/streak_list.dart` | именованный параметр `silenceQualifies` со значением `false` | по умолчанию поведение дословно прежнее, `models.streak-computation#3` держится своим тестом | `computed.streak#1`, `#2` + DEVIATIONS |
| `models/habit.dart` | поле `definition` и нижняя граница окна | у привычки без определения окно прежнее, `models.habit-recompute#3`, `#4` держатся своими тестами | `computed.commitment#1`…`#4` + DEVIATIONS |
| `test/models/habit_test.dart` | `SpyStreakList` дописывает параметр | иначе не компилируется | — |

Запись в `docs/parity/DEVIATIONS.md` — **одна на всю секцию**, в Задаче 3-streaks.7.
`docs/parity/FEATURES.md` не меняется ни строкой.

**Читающее API для «дней без срыва»** (то, что зовёт UI):

```dart
int daysWithoutLapse(Habit habit, {LocalDate? asOf});
```

### Task 12: реестр правил и текущая серия (3-streaks.1)

`StreakList` умеет отдавать лучшие серии и не умеет отдать ту, в которой мы
сейчас. Это и есть счётчик «дней без срыва».

**Files:**
- Modify: `docs/extensions/COMPUTED.md` (в конец файла)
- Modify: `packages/uhabits_core/lib/src/models/streak_list.dart` (после `getBest`, строка 28)
- Test: `packages/uhabits_core/test/computed/current_streak_test.dart` (создать)

**Interfaces:**
- Consumes: `Streak`, `LocalDate`, `EntryList.getByInterval`.
- Produces: `Streak? StreakList.getCurrent(LocalDate day)`.

- [ ] **Шаг 1: завести оба раздела реестра невыполненными**

В конец `docs/extensions/COMPUTED.md` дописать. Галочки ставятся в
Задаче 3-streaks.7 — до тех пор `tool/parity_coverage.dart --verify` их не
проверяет и остаётся зелёным:

```markdown
- [ ] `computed.commitment`
1. `computed.commitment#1` Окно пересчёта начинается не позже дня обязательства: у привычки без единой записи серии и баллы существуют со дня решения, а не с сегодняшнего дня.
2. `computed.commitment#2` День обязательства окно только расширяет назад: запись старше него границу не теряет.
3. `computed.commitment#3` Без определения и у вида без дня обязательства граница прежняя — старейшая запись или сегодня.
4. `computed.commitment#4` Определение не входит ни в равенство привычек, ни в hashCode, ни в copyFrom.
5. `computed.commitment#5` Определение прикрепляется к живой привычке при открытии приложения, до первого пересчёта.

- [ ] `computed.streak`
1. `computed.streak#1` У вида, для которого молчание есть успех, день без записи входит в серию at-most.
2. `computed.streak#2` Для всех прочих привычек молчание серию по-прежнему рвёт: параметр выключен по умолчанию.
3. `computed.streak#3` Текущая серия — та, что накрывает заданный день; ответ не зависит от порядка, в котором getBest оставил внутренний список.
4. `computed.streak#4` Дней без срыва есть прошедшее время от начала серии до заданного дня; день начала даёт ноль. Хвост окна, уходящий на 30 дней вперёд, в счёт не идёт.
5. `computed.streak#5` День, который ни в одну серию не входит, даёт ноль.
```

- [ ] **Шаг 2: написать падающий тест**

Создать `packages/uhabits_core/test/computed/current_streak_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  late LocalDate today;
  late EntryList entries;
  late StreakList streaks;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = EntryList();
    streaks = StreakList();
  });

  tearDown(resetToday);

  /// Ровно то, что передаёт Habit.recompute: вычисленные записи, нижняя
  /// граница и сегодня + 30. EntryList.getByInterval сам отдаёт UNKNOWN за
  /// дни, которых в нём нет, так что подделывать нечего.
  void recomputeBoolean() {
    streaks.recompute(
      entries.getByInterval,
      today.minus(60),
      today.plus(30),
      false,
      0.0,
      NumericalHabitType.atLeast,
    );
  }

  group('computed.streak', () {
    test('#3 the current streak is the one that covers the day', () {
      for (final int offset in <int>[0, 1, 2, 10, 11]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      expect(streaks.getCurrent(today), Streak(today.minus(2), today),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(1)), Streak(today.minus(2), today),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(11)),
          Streak(today.minus(11), today.minus(10)),
          reason: 'computed.streak#3');
    });

    test('#3 a day between two streaks belongs to neither', () {
      entries.add(Entry(today, Entry.yesManual));
      entries.add(Entry(today.minus(2), Entry.yesManual));
      recomputeBoolean();

      expect(streaks.getCurrent(today.minus(1)), isNull,
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(30)), isNull,
          reason: 'computed.streak#3');
      expect(StreakList().getCurrent(today), isNull,
          reason: 'computed.streak#3');
    });

    test('#3 the answer survives the reordering getBest leaves behind', () {
      // Длинная старая серия и короткая сегодняшняя: после getBest(1)
      // внутренний список начинается с длинной, то есть НЕ с текущей.
      for (final int offset in <int>[0, 5, 6, 7, 8, 9]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      expect(streaks.getBest(1).single, Streak(today.minus(9), today.minus(5)),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today), Streak(today, today),
          reason: 'computed.streak#3');
    });
  });
}
```

- [ ] **Шаг 3: запустить, убедиться что падает**

```bash
cd packages/uhabits_core && dart test test/computed/current_streak_test.dart
```
Ожидается: FAIL на компиляции — `The method 'getCurrent' isn't defined for the
type 'StreakList'`.

- [ ] **Шаг 4: написать getCurrent**

В `packages/uhabits_core/lib/src/models/streak_list.dart` вставить сразу после
закрывающей скобки `getBest` (строка 28) и пустой строки:

```dart
  /// Серия, накрывающая [day], или null, если день не входит ни в одну.
  ///
  /// Расширение порта: Kotlin отдаёт наружу только [getBest], а счётчик «дней
  /// без срыва» — это именно текущая серия, а не самая длинная
  /// (`computed.streak#3`).
  ///
  /// Перебором, а не по первому элементу: [getBest] переупорядочивает
  /// внутренний список как побочный эффект (`_list.setRange`, см.
  /// `models.streak-best#5`), поэтому после любого его вызова первая серия в
  /// списке — не самая новая.
  Streak? getCurrent(LocalDate day) {
    for (final Streak streak in _list) {
      if (streak.start <= day && day <= streak.end) return streak;
    }
    return null;
  }
```

- [ ] **Шаг 5: запустить, убедиться что проходит**

```bash
cd packages/uhabits_core && dart test test/computed/current_streak_test.dart
```
Ожидается: PASS, три теста.

- [ ] **Шаг 6: мутация**

Заменить тело цикла на `return _list.isEmpty ? null : _list.first;` (то есть
весь `for` — на эту строку). Ожидается: FAIL в тесте «the answer survives the
reordering getBest leaves behind» — `Expected: Streak(start=2015-01-25,
end=2015-01-25) Actual: Streak(start=2015-01-16, end=2015-01-20)`. Вернуть
обратной заменой: строку `return _list.isEmpty ? null : _list.first;` заменить
на исходный `for`-цикл.

- [ ] **Шаг 7: коммит**

```bash
git add packages/uhabits_core docs/extensions/COMPUTED.md
git commit -m "Ask the streak list which streak covers a given day"
```

---

### Task 13: молчание засчитывается в серию — по требованию (3-streaks.2)

Фильтр at-most выкидывает `UNKNOWN` безусловно. Для «не больше двух сигарет»
это правильно (день, о котором ничего не известно, ничего не подтверждает), для
воздержания — ровно наоборот. Поэтому не правка правила, а параметр, по
умолчанию выключенный: паритетное поведение остаётся дословным.

**Files:**
- Modify: `packages/uhabits_core/lib/src/models/streak_list.dart:38-56`
- Modify: `packages/uhabits_core/test/models/habit_test.dart:111-147` (`SpyStreakList`, иначе не компилируется)
- Test: `packages/uhabits_core/test/computed/current_streak_test.dart` (новая группа)

**Interfaces:**
- Consumes: `Entry.unknown`.
- Produces:
  ```dart
  void StreakList.recompute(
    List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
    LocalDate from,
    LocalDate to,
    bool isNumerical,
    double targetValue,
    NumericalHabitType targetType, {
    bool silenceQualifies = false,
  });
  ```

- [ ] **Шаг 1: написать падающий тест**

В `test/computed/current_streak_test.dart`, новой группой после `computed.streak`:

```dart
  group('computed.streak silence', () {
    void recomputeAtMost({required bool silenceQualifies}) {
      streaks.recompute(
        entries.getByInterval,
        today.minus(10),
        today.plus(30),
        true,
        0.0,
        NumericalHabitType.atMost,
        silenceQualifies: silenceQualifies,
      );
    }

    test('#1 with silenceQualifies a day holding nothing extends the streak',
        () {
      // Ни одной записи вообще: для воздержания это сорок чистых дней, а не
      // отсутствие истории.
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today),
          Streak(today.minus(10), today.plus(30)),
          reason: 'computed.streak#1');

      // Срыв четыре дня назад режет её надвое, и молчание по обе стороны
      // остаётся успехом.
      entries.add(Entry(today.minus(4), 1000));
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today), Streak(today.minus(3), today.plus(30)),
          reason: 'computed.streak#1');
      expect(streaks.getCurrent(today.minus(4)), isNull,
          reason: 'computed.streak#1');
      expect(streaks.getCurrent(today.minus(5)),
          Streak(today.minus(10), today.minus(5)),
          reason: 'computed.streak#1');
    });

    test('#2 by default silence still breaks an at-most streak', () {
      entries.add(Entry(today, Entry.no));
      entries.add(Entry(today.minus(2), Entry.no));
      recomputeAtMost(silenceQualifies: false);

      expect(streaks.getCurrent(today), Streak(today, today),
          reason: 'computed.streak#2');
      expect(streaks.getCurrent(today.minus(1)), isNull,
          reason: 'computed.streak#2');
      expect(streaks.getBest(10).length, 2, reason: 'computed.streak#2');

      // И то же самое, когда параметр не передан вовсе: умолчание есть
      // паритетное поведение (`models.streak-computation#3`).
      streaks.recompute(
        entries.getByInterval,
        today.minus(10),
        today.plus(30),
        true,
        0.0,
        NumericalHabitType.atMost,
      );
      expect(streaks.getBest(10).length, 2, reason: 'computed.streak#2');
    });
  });
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd packages/uhabits_core && dart test test/computed/current_streak_test.dart
```
Ожидается: FAIL на компиляции — `No named parameter with the name
'silenceQualifies'`.

- [ ] **Шаг 3: добавить параметр**

В `packages/uhabits_core/lib/src/models/streak_list.dart` заменить

```dart
    NumericalHabitType targetType,
  ) {
```

на

```dart
    NumericalHabitType targetType, {
    bool silenceQualifies = false,
  }) {
```

и в документирующем комментарии над `recompute` дописать абзац:

```dart
  /// [silenceQualifies] — расширение порта, выключенное по умолчанию, чтобы
  /// каждая портированная привычка считалась дословно как в Kotlin. Его
  /// включает вид, для которого день без записи и есть успех: воздержание
  /// ничего не пишет, пока его держат (`computed.streak#1`, `#2`).
```

- [ ] **Шаг 4: пропустить UNKNOWN через фильтр**

Там же, в `.where(...)`, заменить

```dart
              case NumericalHabitType.atMost:
                return value != Entry.unknown && value / 1000.0 <= targetValue;
```

на

```dart
              case NumericalHabitType.atMost:
                // Оригинал исключает UNKNOWN безусловно
                // (`models.streak-computation#3`), и для «не больше двух
                // сигарет» это верно: день, о котором ничего не известно,
                // ничего не подтверждает. Для вида, где молчание и есть
                // успех, — ровно наоборот.
                if (value == Entry.unknown) return silenceQualifies;
                return value / 1000.0 <= targetValue;
```

- [ ] **Шаг 5: починить шпион, иначе ядро не компилируется**

В `packages/uhabits_core/test/models/habit_test.dart`, в `SpyStreakList`,
заменить

```dart
  NumericalHabitType? capturedTargetType;

  @override
  void recompute(
    List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
    LocalDate from,
    LocalDate to,
    bool isNumerical,
    double targetValue,
    NumericalHabitType targetType,
  ) {
```

на

```dart
  NumericalHabitType? capturedTargetType;
  bool? capturedSilenceQualifies;

  @override
  void recompute(
    List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
    LocalDate from,
    LocalDate to,
    bool isNumerical,
    double targetValue,
    NumericalHabitType targetType, {
    bool silenceQualifies = false,
  }) {
```

и в теле — заменить

```dart
    capturedTargetType = targetType;
    super.recompute(
      getEntriesByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
    );
```

на

```dart
    capturedTargetType = targetType;
    capturedSilenceQualifies = silenceQualifies;
    super.recompute(
      getEntriesByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
      silenceQualifies: silenceQualifies,
    );
```

- [ ] **Шаг 6: запустить, убедиться что проходит**

```bash
cd packages/uhabits_core && dart test test/computed/current_streak_test.dart test/models/streak_list_test.dart test/models/habit_test.dart
```
Ожидается: PASS всё, включая паритетный `#3 for a numerical AT_MOST habit
UNKNOWN never qualifies` — он и есть доказательство, что умолчание не сдвинулось.

- [ ] **Шаг 7: мутация**

Заменить `if (value == Entry.unknown) return silenceQualifies;` на
`if (value == Entry.unknown) return false;`. Ожидается: FAIL в
«#1 with silenceQualifies a day holding nothing extends the streak» —
`Expected: Streak(start=2015-01-15, end=2015-02-24) Actual: <null>`. Вернуть
обратной заменой `return false;` → `return silenceQualifies;`.

Вторая мутация: заменить `bool silenceQualifies = false,` на
`bool silenceQualifies = true,`. Ожидается: FAIL в паритетном
`test/models/streak_list_test.dart` `#3 for a numerical AT_MOST habit UNKNOWN
never qualifies` — `Expected: <3> Actual: <2>` (две серии сливаются через
пропущенный день). Вернуть обратной заменой `= true,` → `= false,`.

- [ ] **Шаг 8: коммит**

```bash
git add packages/uhabits_core
git commit -m "Let a kind declare that a silent day counts toward its streak"
```

---

### Task 14: привычка носит своё определение (3-streaks.3)

`Habit.recompute()` зовут пятнадцать мест — команды, импорт, смена суток, —
и ни одно не видит `DefinitionRepository`. Значит определение должно ехать на
самой привычке. Поле не входит ни в `==`, ни в `hashCode`, ни в `copyFrom`:
`EditHabitCommand` делает `habit.copyFrom(modified)`, где `modified` собран
формой и определения не несёт, — копирование стёрло бы день обязательства
живой привычки.

**Files:**
- Modify: `packages/uhabits_core/lib/src/computed/habit_definition.dart:6-24`
- Modify: `packages/uhabits_core/lib/src/models/habit.dart:1-24`, `:76-90`
- Test: `packages/uhabits_core/test/computed/commitment_window_test.dart` (создать)

**Interfaces:**
- Consumes: `HabitDefinition`, `ComputedKind`.
- Produces:
  ```dart
  HabitDefinition? Habit.definition;          // поле, по умолчанию null
  bool ComputedKind.silenceQualifies;         // sleep: false, abstinence: true
  ```

- [ ] **Шаг 1: написать падающий тест**

Создать `packages/uhabits_core/test/computed/commitment_window_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  late LocalDate today;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
  });

  tearDown(resetToday);

  Habit buildHabit() => MemoryModelFactory().buildHabit();

  group('computed.commitment', () {
    test('#4 a fresh habit carries no definition', () {
      expect(buildHabit().definition, isNull,
          reason: 'computed.commitment#4');
    });

    test('#4 the definition is outside equality, hashCode and copyFrom', () {
      final Habit plain = buildHabit()..name = 'No sugar';
      final Habit marked = buildHabit()
        ..name = 'No sugar'
        ..uuid = plain.uuid
        ..definition = HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: today.minus(40).daysSince2000,
        );

      expect(marked, plain, reason: 'computed.commitment#4');
      expect(marked.hashCode, plain.hashCode, reason: 'computed.commitment#4');

      // copyFrom не переносит его ни туда, ни обратно: форма редактирования
      // собирает привычку-черновик без определения, и её копирование в живую
      // стёрло бы день обязательства.
      marked.copyFrom(plain);
      expect(marked.definition?.committedFrom, today.minus(40).daysSince2000,
          reason: 'computed.commitment#4');
      plain.copyFrom(marked);
      expect(plain.definition, isNull, reason: 'computed.commitment#4');
    });

    test('#1 a kind says whether silence is success', () {
      expect(ComputedKind.abstinence.silenceQualifies, isTrue,
          reason: 'computed.commitment#1');
      expect(ComputedKind.sleep.silenceQualifies, isFalse,
          reason: 'computed.commitment#1');
    });
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd packages/uhabits_core && dart test test/computed/commitment_window_test.dart
```
Ожидается: FAIL на компиляции — `The setter 'definition' isn't defined for the
type 'Habit'` и `The getter 'silenceQualifies' isn't defined for the type
'ComputedKind'`.

- [ ] **Шаг 3: вид говорит, считается ли молчание успехом**

В `packages/uhabits_core/lib/src/computed/habit_definition.dart` заменить

```dart
enum ComputedKind {
  sleep('sleep'),
  abstinence('abstinence');

  const ComputedKind(this.wireName);

  final String wireName;
```

на

```dart
enum ComputedKind {
  sleep('sleep', silenceQualifies: false),
  abstinence('abstinence', silenceQualifies: true);

  const ComputedKind(this.wireName, {required this.silenceQualifies});

  final String wireName;

  /// Считается ли день, о котором ничего не записано, удавшимся.
  ///
  /// Свойство вида, а не привычки: непрослеженная ночь — не хорошая ночь, а
  /// день, в который человек не отметил срыв, — это ровно тот день, ради
  /// которого он и обязался. В базу не идёт: туда идёт только [wireName].
  final bool silenceQualifies;
```

- [ ] **Шаг 4: добавить поле привычке**

В `packages/uhabits_core/lib/src/models/habit.dart` дописать импорт первой
строкой относительной группы (перед `import '../time/local_date.dart';`):

```dart
import '../computed/habit_definition.dart';
```

В комментарии класса заменить

```dart
/// `equals`/`hashCode` are hand written in Kotlin too: they cover the fourteen
/// model fields and deliberately ignore [computedEntries], [originalEntries],
/// [scores], [streaks] and [observable].
```

на

```dart
/// `equals`/`hashCode` are hand written in Kotlin too: they cover the fourteen
/// model fields and deliberately ignore [computedEntries], [originalEntries],
/// [scores], [streaks] and [observable] — and [definition], which the Kotlin
/// data class does not have at all.
```

Сразу после `ModelObservable observable = ModelObservable();` вставить:

```dart
  /// Определение, по которому приложение считает дни этой привычки, или null
  /// у обычной.
  ///
  /// Едет на модели, а не спрашивается у репозитория, потому что [recompute]
  /// зовут пятнадцать мест — команды, импорт, смена суток, — и ни одно из них
  /// репозитория не видит. Прикрепляется одной дверью,
  /// `computed/attach_definition.dart`.
  ///
  /// Не участвует ни в [==], ни в [hashCode], ни в [copyFrom] — ровно как
  /// четыре сотрудника выше. Для `copyFrom` это не только паритет:
  /// `EditHabitCommand` делает `habit.copyFrom(modified)`, где `modified`
  /// собран формой и определения не несёт, так что копирование стирало бы
  /// день обязательства живой привычки (`computed.commitment#4`).
  HabitDefinition? definition;
```

- [ ] **Шаг 5: запустить, убедиться что проходит**

```bash
cd packages/uhabits_core && dart test test/computed/commitment_window_test.dart test/models/habit_test.dart test/computed/habit_definition_test.dart
```
Ожидается: PASS, включая паритетные тесты равенства и `copyFrom`.

- [ ] **Шаг 6: мутация**

В `copyFrom` дописать строкой перед `uuid = other.uuid;`:
`definition = other.definition;`. Ожидается: FAIL в «#4 the definition is
outside equality, hashCode and copyFrom» — `Expected: <5473> Actual: <null>`.
Вернуть обратной заменой: удалить строку `definition = other.definition;`.

Вторая мутация: в `operator ==` дописать
`if (definition != other.definition) return false;` перед `return true;`.
Ожидается: FAIL там же — `Expected: Habit ... Actual: Habit ...` на
`expect(marked, plain)`. Вернуть обратной заменой.

- [ ] **Шаг 7: коммит**

```bash
git add packages/uhabits_core
git commit -m "Let a habit carry the definition that computes its days"
```

---

### Task 15: окно пересчёта начинается со дня обязательства (3-streaks.4)

Нижняя граница — первая запись. У привычки, которая ничего не пишет, пока её
держат, первой записи нет: сорока чистых дней не существует, а серия
начинается со срыва. Спека называет это ограничением формы, а не дефектом
общей машинерии (`UNKNOWN` пишет и сам оригинал).

**Files:**
- Modify: `packages/uhabits_core/lib/src/models/habit.dart:135-158`
- Test: `packages/uhabits_core/test/computed/commitment_window_test.dart`

**Interfaces:**
- Consumes: `Habit.definition`, `HabitDefinition.committedFrom`, `ComputedKind.silenceQualifies`, `StreakList.recompute(..., silenceQualifies:)`.
- Produces: поведение `Habit.recompute()`; новых подписей нет.

- [ ] **Шаг 1: написать падающий тест**

В `test/computed/commitment_window_test.dart` дописать в группу
`computed.commitment`. Импортировать дополнительно `habit_type.dart`,
`entry.dart`, `streak.dart`:

```dart
    Habit buildAbstinence({required int committedFrom}) => buildHabit()
      ..name = 'No sugar'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
      );

    test('#1 forty clean days before the first lapse exist', () {
      final Habit habit =
          buildAbstinence(committedFrom: today.minus(40).daysSince2000);
      habit.recompute();

      // Ни одной записи — и всё равно есть серия, и она начинается в день
      // решения, а не сегодня.
      expect(habit.computedEntries.getKnown(), isEmpty,
          reason: 'computed.commitment#1');
      expect(habit.streaks.getCurrent(today)?.start, today.minus(40),
          reason: 'computed.commitment#1');
    });

    test('#2 the commitment day only widens the window backwards', () {
      final Habit habit =
          buildAbstinence(committedFrom: today.minus(10).daysSince2000);
      habit.originalEntries.add(Entry(today.minus(50), 1000));
      habit.recompute();

      // Срыв старше дня обязательства историю не теряет: граница осталась на
      // записи, потому что она старше.
      expect(habit.streaks.getCurrent(today)?.start, today.minus(49),
          reason: 'computed.commitment#2');
    });

    test('#3 a habit without a definition keeps the ported window', () {
      final Habit habit = buildHabit()
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 0.0;
      habit.recompute();

      expect(habit.streaks.getBest(10), isEmpty,
          reason: 'computed.commitment#3');

      // И вид без дня обязательства — тоже: у сна committedFrom есть null.
      habit.definition = const HabitDefinition(kind: ComputedKind.sleep);
      habit.recompute();
      expect(habit.streaks.getBest(10), isEmpty,
          reason: 'computed.commitment#3');
    });
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd packages/uhabits_core && dart test test/computed/commitment_window_test.dart
```
Ожидается: FAIL — «#1 forty clean days before the first lapse exist»:
`Expected: LocalDate(2014-12-16) Actual: <null>` (серий нет вовсе: окно
начинается сегодня и `silenceQualifies` не передан).

- [ ] **Шаг 3: подвинуть нижнюю границу и передать признак**

В `packages/uhabits_core/lib/src/models/habit.dart`, в `recompute()`, заменить

```dart
    var from = entries.isEmpty ? today : entries.last.date;
    if (from.isNewerThan(to)) from = to;
```

на

```dart
    var from = entries.isEmpty ? today : entries.last.date;
    // Расширение: у вычисляемой привычки нижняя граница не может опираться на
    // записи. Привычка, которая ничего не пишет, пока её держат, старейшей
    // записи не имеет, и её сорок чистых дней не существовали бы
    // (`computed.commitment#1`). Окно только расширяется назад: запись старше
    // дня обязательства границу не теряет (`computed.commitment#2`).
    final int? committedFrom = definition?.committedFrom;
    if (committedFrom != null) {
      final LocalDate committed = LocalDate(committedFrom);
      if (committed.isOlderThan(from)) from = committed;
    }
    if (from.isNewerThan(to)) from = to;
```

и заменить

```dart
    streaks.recompute(
      computedEntries.getByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
    );
```

на

```dart
    streaks.recompute(
      computedEntries.getByInterval,
      from,
      to,
      isNumerical,
      targetValue,
      targetType,
      // Молчание — свойство вида, а не привычки: у сна непрослеженная ночь не
      // хорошая ночь, у воздержания день без отметки и есть тот день, ради
      // которого обязывались (`computed.streak#1`).
      silenceQualifies: definition?.kind.silenceQualifies ?? false,
    );
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

```bash
cd packages/uhabits_core && dart test test/computed/ test/models/habit_test.dart test/models/streak_list_test.dart test/models/score_list_test.dart
```
Ожидается: PASS. Паритетные `models.habit-recompute#3` и `#4` проходят без
правки — у привычки без определения ветка не срабатывает.

- [ ] **Шаг 5: мутация**

Заменить `if (committed.isOlderThan(from)) from = committed;` на
`from = committed;`. Ожидается: FAIL в «#2 the commitment day only widens the
window backwards» — `Expected: LocalDate(2014-12-07) Actual:
LocalDate(2015-01-15)` (история старше дня решения отрезана). Вернуть обратной
заменой `from = committed;` → `if (committed.isOlderThan(from)) from = committed;`.

Вторая мутация: заменить `silenceQualifies: definition?.kind.silenceQualifies ?? false,`
на `silenceQualifies: false,`. Ожидается: FAIL в «#1 forty clean days before
the first lapse exist» — `Expected: LocalDate(2014-12-16) Actual: <null>`.
Вернуть обратной заменой.

- [ ] **Шаг 6: коммит**

```bash
git add packages/uhabits_core
git commit -m "Start the recompute window at the day of the commitment"
```

---

### Task 16: «дней без срыва» как читающее API (3-streaks.5)

То, что зовёт UI, и **единственная** такая функция: в приложении своей копии
нет — раздел списка зовёт эту. Считается по сегодняшний день, а не длиной серии:
окно уходит на 30 дней вперёд (`models.habit-recompute#2`), и у привычки, где
молчание — успех, текущая серия всегда дотягивается до конца окна.
`current.length` дал бы сегодняшним сорока дням семьдесят один.

**Семантика — прошедшее время.** «Сорок чистых дней до первого срыва» это
`start.daysUntil(day)`, без `+ 1`: день обязательства даёт ноль, завтра —
единицу, срыв сегодня — ноль. Не порядковый номер сегодняшнего дня. Решено один
раз и здесь, потому что иначе экран показывает одно число, а серия в карточке
серий имеет другую длину.

**Files:**
- Create: `packages/uhabits_core/lib/src/computed/days_without_lapse.dart`
- Modify: `packages/uhabits_core/lib/uhabits_core.dart` (секция `// Computed habits`)
- Test: `packages/uhabits_core/test/computed/current_streak_test.dart` (новая группа)

**Interfaces:**
- Consumes: `Habit.streaks`, `StreakList.getCurrent`, `getToday()`.
- Produces:
  ```dart
  int daysWithoutLapse(Habit habit, {LocalDate? asOf});
  ```
  Импорт для UI: `package:uhabits_core/src/computed/days_without_lapse.dart`.

- [ ] **Шаг 1: написать падающий тест**

В `test/computed/current_streak_test.dart` дописать новой группой (добавив
импорты `days_without_lapse.dart`, `habit.dart`, `habit_definition.dart`,
`memory_model_factory.dart`):

```dart
  group('computed.streak days without a lapse', () {
    Habit buildAbstinence(int committedFromOffset) =>
        MemoryModelFactory().buildHabit()
          ..name = 'No sugar'
          ..type = HabitType.numerical
          ..targetType = NumericalHabitType.atMost
          ..targetValue = 0.0
          ..definition = HabitDefinition(
            kind: ComputedKind.abstinence,
            committedFrom: today.minus(committedFromOffset).daysSince2000,
          );

    test('#4 counts up to today and ignores the future tail of the window',
        () {
      final Habit habit = buildAbstinence(40);
      habit.recompute();

      // Серия тянется до today + 30, но дней без срыва — сорок.
      expect(habit.streaks.getCurrent(today)?.end, today.plus(30),
          reason: 'computed.streak#4');
      expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');
    });

    test('#4 a lapse restarts the count the next day', () {
      final Habit habit = buildAbstinence(40);
      habit.originalEntries.add(Entry(today.minus(10), 1000));
      habit.recompute();

      // Срыв был десять дней назад: серия началась девять дней назад, и
      // прошедшего времени в ней девять дней.
      expect(daysWithoutLapse(habit), 9, reason: 'computed.streak#4');
      expect(daysWithoutLapse(habit, asOf: today.minus(11)), 29,
          reason: 'computed.streak#4');
    });

    test('#4 a commitment made for tomorrow gives zero, not a negative', () {
      // Перенесено из раздела списка вместе с функцией: арифметика счётчика
      // живёт там же, где счётчик, и «обещание в будущем» проверяется тут.
      final Habit habit = MemoryModelFactory().buildHabit()
        ..name = 'No sugar'
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 0.0
        ..definition = HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: today.plus(1).daysSince2000,
        );
      habit.recompute();

      expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#4');
    });

    test('#5 a lapse today gives zero', () {
      final Habit habit = buildAbstinence(40);
      habit.originalEntries.add(Entry(today, 1000));
      habit.recompute();

      expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#5');

      // И обычная привычка без единой серии тоже даёт ноль, а не падает.
      expect(daysWithoutLapse(MemoryModelFactory().buildHabit()..recompute()),
          0,
          reason: 'computed.streak#5');
    });
  });
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd packages/uhabits_core && dart test test/computed/current_streak_test.dart
```
Ожидается: FAIL на компиляции — `Undefined name 'daysWithoutLapse'`.

- [ ] **Шаг 3: написать функцию**

Создать `packages/uhabits_core/lib/src/computed/days_without_lapse.dart`:

```dart
import '../models/habit.dart';
import '../models/streak.dart';
import '../time/local_date.dart';

/// Сколько дней прошло без срыва к [asOf] — по умолчанию к сегодняшнему дню.
///
/// Прошедшее время, а не порядковый номер дня: день начала серии даёт ноль,
/// следующий — единицу. «Сорок чистых дней до первого срыва» есть
/// `committedFrom.daysUntil(today)` (`computed.streak#4`).
///
/// Ноль, если [asOf] не входит ни в одну серию: сегодняшний срыв обнуляет счёт
/// сегодня же, а не завтра (`computed.streak#5`).
///
/// Считается по [asOf], а не длиной серии, и это не мелочь. Окно пересчёта
/// уходит на тридцать дней вперёд (`models.habit-recompute#2`), а у вида, для
/// которого молчание есть успех, будущие дни в серию входят все: `length`
/// показывал бы сорок первый день как семьдесят первый (`computed.streak#4`).
///
/// Отдельной функцией, а не методом [StreakList]: «срыв» — слово воздержания,
/// а `StreakList` — портированный класс, общий для всех привычек. Кому нужен
/// не счёт, а дата начала — зовёт `habit.streaks.getCurrent(getToday())`.
int daysWithoutLapse(Habit habit, {LocalDate? asOf}) {
  final LocalDate day = asOf ?? getToday();
  final Streak? current = habit.streaks.getCurrent(day);
  if (current == null) return 0;
  return current.start.daysUntil(day);
}
```

В `packages/uhabits_core/lib/uhabits_core.dart`, в секцию `// Computed habits`,
дописать строкой (перед `export 'src/computed/definition_repository.dart';`):

```dart
export 'src/computed/days_without_lapse.dart';
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

```bash
cd packages/uhabits_core && dart test test/computed/
```
Ожидается: PASS.

- [ ] **Шаг 5: мутация**

Заменить `return current.start.daysUntil(day);` на `return current.length;`.
Ожидается: FAIL в «#4 counts up to today and ignores the future tail of the
window» — `Expected: <40> Actual: <71>`. Вернуть обратной заменой
`return current.length;` → `return current.start.daysUntil(day);`.

Вторая мутация: `return current.start.daysUntil(day);` →
`return current.start.daysUntil(day) + 1;`. Ожидается: FAIL там же —
`Expected: <40> Actual: <41>`, и это ровно тот спор, который решён один раз:
владелец сказал «сорок чистых дней до первого срыва», то есть прошедшее время.
Вернуть обратной заменой.

- [ ] **Шаг 6: коммит**

```bash
git add packages/uhabits_core
git commit -m "Answer how many days the habit has been kept without a lapse"
```

---

### Task 17: определение прикрепляется при загрузке (3-streaks.6)

Поле есть, читать его некому: `SQLiteHabitList` строит привычки из строк
`Habits` и о `HabitDefinitions` не знает. Прикрепление делается одной дверью в
слое (не в портированном списке) и зовётся из `AppScope.open` до первого
пересчёта.

**Files:**
- Create: `packages/uhabits_core/lib/src/computed/attach_definition.dart`
- Modify: `packages/uhabits_core/lib/uhabits_core.dart` (секция `// Computed habits`)
- Modify: `app/lib/state/app_scope.dart` (объявление `definitions` переносится выше цикла `habit.recompute()`)
- Test: `app/test/state/computed_commitment_wiring_test.dart` (создать)

**Interfaces:**
- Consumes: `DefinitionRepository.forHabit`, `Habit.definition`,
  `applyLapseScoring` (Задача 8), `lapseDayValue` (Задача 5 — в тесте, чтобы
  записать настоящий срыв без свода, которого ещё нет).
- Produces:
  ```dart
  void attachDefinition(Habit habit, DefinitionRepository definitions);
  void attachDefinitions(Iterable<Habit> habits, DefinitionRepository definitions);
  ```

- [ ] **Шаг 1: написать падающий тест**

Создать `app/test/state/computed_commitment_wiring_test.dart`:

```dart
/// Определение доезжает до живой привычки.
///
/// Поле `Habit.definition` — единственный способ, которым пересчёт узнаёт день
/// обязательства, и заполняет его ровно одно место: открытие приложения. Если
/// прикрепление отвалится, привычка не сломается заметно — она просто станет
/// считаться с сегодняшнего дня, и «дней без срыва» навсегда останется единицей.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/computed/days_without_lapse.dart';
import 'package:uhabits_core/src/computed/definition_repository.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_commitment');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('a habit loaded at startup knows the day it was committed to', () {
    // Абсолютная дата, а не смещение от сегодня: AppScope.open сам ставит
    // сегодня по часам устройства, так что заморозить его снаружи нельзя.
    final LocalDate committed = LocalDate.ymd(2020, 1, 1);

    final Database db =
        AppDatabase.openAndMigrate('${tempDir.path}/commitment.db');
    final SQLModelFactory factory = SQLModelFactory(db);
    final Habit habit = factory.buildHabit()
      ..name = 'No sugar'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0;
    factory.buildHabitList().add(habit);
    DefinitionRepository(db).save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committed.daysSince2000,
      ),
    );

    final AppScope scope = AppScope.open(db);
    addTearDown(scope.close);

    final Habit loaded = scope.habitList.getById(habit.id!)!;
    expect(loaded.definition?.kind, ComputedKind.abstinence,
        reason: 'computed.commitment#5');
    expect(loaded.definition?.committedFrom, committed.daysSince2000,
        reason: 'computed.commitment#5');
    // И, главное, пересчёт на старте уже это учёл: без прикрепления счёт был
    // бы равен единице — окно началось бы сегодня.
    expect(daysWithoutLapse(loaded), committed.daysUntil(getToday()),
        reason: 'computed.commitment#5');
    expect(daysWithoutLapse(loaded), greaterThan(2000),
        reason: 'computed.commitment#5');

    // И включатель деления пополам — там же, одной дверью: правило
    // `computed.lapse-score#11` обязано быть процитировано и юнит-тестом
    // функции, и тестом проводки, иначе цитата означает «функция работает», а
    // не «фича включена» (`computed.lapse-score#12`).
    loaded.originalEntries.add(Entry(getToday(), 1000));
    loaded.recompute();
    expect(loaded.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11 — привычка, поднятая с диска, '
            'считается делением, а не затуханием порта');
    expect(loaded.scores[getToday()].value, lessThan(0.6),
        reason: 'computed.lapse-score#12 — и это видно на настоящем балле');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd app && flutter test test/state/computed_commitment_wiring_test.dart
```
Ожидается: FAIL — `Expected: <ComputedKind.abstinence> Actual: <null>`
(после починки компиляции импорта `days_without_lapse.dart` — он уже есть с
Задачи 3-streaks.5).

- [ ] **Шаг 3: написать дверь**

Создать `packages/uhabits_core/lib/src/computed/attach_definition.dart`:

```dart
import '../models/habit.dart';
import 'definition_repository.dart';
import 'lapse_scoring.dart';

/// Прикрепляет к живой привычке её определение.
///
/// Одна дверь, а не строчка в каждом месте загрузки: правило «живая привычка
/// знает, что она вычисляемая» разъедется по местам ровно так же, как разъехались
/// бы правила записи дня, не будь `DayWriter`.
///
/// Не в `SQLiteHabitList`: это портированный класс, чей `_loadRecords`
/// повторяет котлиновский построчно, и знать о боковой таблице ему нечем.
///
/// Незнакомый вид даёт null — [DefinitionRepository.forHabit] отвечает «нечем
/// считать», и привычка считается по паритетному окну. Запись при этом
/// по-прежнему закрыта: её сторожит [DefinitionRepository.isComputed], которому
/// хватает наличия строки (`computed.definition#9`).
void attachDefinition(Habit habit, DefinitionRepository definitions) {
  final int? id = habit.id;
  if (id == null) return;
  habit.definition = definitions.forHabit(id);
  // Арифметика вида — часть определения, а не отдельная память: объект
  // привычки переживает и снятие определения, и восстановление копии, и
  // включатель, вызываемый где-то ещё, был бы вторым местом, где живёт одно
  // правило (`computed.lapse-score#11`).
  applyLapseScoring(habit, habit.definition);
}

/// То же для всего списка.
///
/// Не пересчитывает: зовущий пересчитывает всё равно и сразу, а лишний обход
/// всей истории на старте стоит дороже этой строчки.
void attachDefinitions(
  Iterable<Habit> habits,
  DefinitionRepository definitions,
) {
  for (final Habit habit in habits) {
    attachDefinition(habit, definitions);
  }
}
```

В `packages/uhabits_core/lib/uhabits_core.dart`, в секцию `// Computed habits`,
дописать первой строкой:

```dart
export 'src/computed/attach_definition.dart';
```

- [ ] **Шаг 4: позвать её на старте, до первого пересчёта**

В `app/lib/state/app_scope.dart` заменить

```dart
    preferences.lastAppVersion = appVersionCode;
    setToday(computeToday(preferences.midnightDelayHours, 0));
    for (final habit in habitList) {
      habit.recompute();
    }
```

на

```dart
    preferences.lastAppVersion = appVersionCode;
    setToday(computeToday(preferences.midnightDelayHours, 0));
    // Определение — до первого пересчёта, а не после: окно вычисляемой
    // привычки начинается со дня обязательства, и привычка, у которой ещё нет
    // ни одной записи, посчиталась бы пустой (`computed.commitment#5`).
    final definitions = DefinitionRepository(database);
    attachDefinitions(habitList, definitions);
    for (final habit in habitList) {
      habit.recompute();
    }
```

К этому моменту хвост `AppScope.open` уже переписан Задачей 11: там стоит
`late final AppScope scope; scope = AppScope._( … ); return scope;`, и внутри
этого вызова `definitions:` берёт имя, объявленное ниже по тексту. Поэтому
объявление **переносится** наверх, а не дублируется: строку

```dart
    final definitions = DefinitionRepository(database);
```

из хвоста убрать, оставив в нём только использование имени
(`definitions: definitions,`). Второе объявление в той же области видимости
даст `Error: 'definitions' is already declared`, а Задача 19 повесит рядом с
поднятым `definitions` ещё и `lapses`.

Добавить импорт:

```dart
import 'package:uhabits_core/src/computed/attach_definition.dart';
```

- [ ] **Шаг 5: запустить, убедиться что проходит**

```bash
cd app && flutter test test/state/
```
Ожидается: PASS — новый тест и все соседние `computed_*_test.dart`.

- [ ] **Шаг 6: мутация**

Убрать строку `attachDefinitions(habitList, definitions);`. Ожидается: FAIL —
`Expected: <ComputedKind.abstinence> Actual: <null>`. Вернуть обратной заменой.

Мутация включателя: убрать строку `applyLapseScoring(habit, habit.definition);`
из `attachDefinition`. Ожидается: FAIL на балле —
`Expected: a value less than <0.6> Actual: <0.948…>`, то есть деление пополам
существует в юнит-тесте и выключено в приложении. Вернуть обратной текстовой
заменой.

Вторая мутация: перенести `attachDefinitions(habitList, definitions);` на
строку ПОСЛЕ цикла `for (final habit in habitList) { habit.recompute(); }`.
Ожидается: FAIL на последнем ожидании — `Expected: a value greater than <2000>
Actual: <1>` (определение доехало, но окно уже посчитано без него). Вернуть
перестановкой назад.

- [ ] **Шаг 7: коммит**

```bash
git add packages/uhabits_core app
git commit -m "Attach a habit's definition before the first recompute"
```

---

### Task 18: отклонение записано, реестр закрыт (3-streaks.7)

Три правки в портированных файлах (`models/streak_list.dart`,
`models/habit.dart`) должны читаться как решение, а не как забытая ветка.

**Files:**
- Modify: `docs/parity/DEVIATIONS.md` (в конец, в раздел `## Расширения`, строка 713 и ниже)
- Modify: `docs/extensions/COMPUTED.md` (снять `- [ ]` → `- [x]` у двух разделов)

**Interfaces:**
- Consumes: `tool/parity_coverage.dart --verify`.
- Produces: ничего исполняемого.

- [ ] **Шаг 1: записать отклонение**

В конец `docs/parity/DEVIATIONS.md` дописать:

```markdown
### computed: окно пересчёта и серии знают про день обязательства

Три места портированного ядра узнали про вычисляемую привычку. Ни одно из них
не меняет поведения привычки оригинала, и каждое проверено паритетным тестом,
который прошёл без правки.

`Habit` носит поле `definition` (`models/habit.dart`), которого у котлиновского
`data class` нет. Оно вне `==`, `hashCode` и `copyFrom` — как четыре сотрудника
(`models.habit-fields-defaults#8`), и для `copyFrom` это ещё и необходимость:
`EditHabitCommand` делает `habit.copyFrom(modified)`, где `modified` собран
формой и определения не несёт. Причина, по которой определение едет на модели,
а не спрашивается у репозитория: `recompute()` зовут пятнадцать мест — команды,
импорт, смена суток, свод сна, — и ни одно из них репозитория не видит.
Заполняется поле одной дверью, `computed/attach_definition.dart`, из
`AppScope.open` до первого пересчёта.

`Habit.recompute()` берёт нижнюю границу окна как более раннее из двух: старейшая
запись (`models.habit-recompute#3`) и день обязательства. Окно только
расширяется назад. Причина — та же, что записана в спеке как ограничение формы:
строку со значением `-1` пишет и сам оригинал, так что `entries.last.date`
прибивает границу у любой привычки Loop; а привычка, которая ничего не пишет,
пока её держат, старейшей записи не имеет вовсе. Без этого сорок чистых дней до
первого срыва не существовали бы, а серия начиналась бы со срыва.

`StreakList` получил `getCurrent(day)` и именованный параметр
`silenceQualifies`, выключенный по умолчанию. Kotlin отдаёт наружу только
`getBest(limit)`, отсортированный по длине, и текущей серии из него не достать —
тем более что `getBest` переупорядочивает внутренний список как побочный эффект
(`models.streak-best#5`). Фильтр at-most в оригинале исключает `UNKNOWN`
безусловно (`models.streak-computation#3`), и для «не больше двух сигарет» это
верно; для вида, где молчание и есть успех, — ровно наоборот. Признак взят у
вида (`ComputedKind.silenceQualifies`), а не у привычки: непрослеженная ночь не
есть хорошая ночь, а день без отметки о срыве есть ровно тот день, ради которого
обязывались.

Портированный набор правится в одном месте и только ради компиляции:
`SpyStreakList` (`test/models/habit_test.dart`) переопределяет `recompute`, и
подпись обязана совпасть. Шпион дописывает параметр и передаёт его дальше —
ни одно ожидание портированного теста не меняется.

Влияние на пользователя: none для привычек оригинала — у них `definition` есть
null, обе новые ветки не срабатывают, и оба паритетных теста
(`models.habit-recompute#3`, `models.streak-computation#3`) проходят без правки.
Мутация каждого умолчания роняет именно их — это и есть проверка.
```

- [ ] **Шаг 2: закрыть реестр**

В `docs/extensions/COMPUTED.md` заменить `- [ ] \`computed.commitment\`` на
`- [x] \`computed.commitment\`` и `- [ ] \`computed.streak\`` на
`- [x] \`computed.streak\``.

- [ ] **Шаг 3: проверить, что каждое правило процитировано**

```bash
cd uhabits-flutter && dart tool/parity_coverage.dart --verify
```
Ожидается: `Every checked feature is fully cited.` и exit 0. Если exit 1 —
вывод назовёт правило без теста; дописать цитату в `reason:` того теста,
который его и проверяет, а не заводить новый.

- [ ] **Шаг 4: весь набор**

```bash
cd uhabits-flutter && ./test.sh
```
Ожидается: `==> all green`. `docs/parity/FEATURES.md` в `git diff` не
появляется — проверить `git diff --stat docs/`.

- [ ] **Шаг 5: коммит**

```bash
git add docs
git commit -m "Record why the recompute window and the streak list learned about definitions"
```

---

#### Что эти задачи отдают наружу

```dart
// packages/uhabits_core/lib/src/models/streak_list.dart
Streak? StreakList.getCurrent(LocalDate day);
void StreakList.recompute(
  List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
  LocalDate from,
  LocalDate to,
  bool isNumerical,
  double targetValue,
  NumericalHabitType targetType, {
  bool silenceQualifies = false,
});

// packages/uhabits_core/lib/src/models/habit.dart
HabitDefinition? Habit.definition;   // вне ==, hashCode и copyFrom

// packages/uhabits_core/lib/src/computed/habit_definition.dart
bool ComputedKind.silenceQualifies;  // sleep: false, abstinence: true

// packages/uhabits_core/lib/src/computed/days_without_lapse.dart
int daysWithoutLapse(Habit habit, {LocalDate? asOf});

// packages/uhabits_core/lib/src/computed/attach_definition.dart
void attachDefinition(Habit habit, DefinitionRepository definitions);
void attachDefinitions(Iterable<Habit> habits, DefinitionRepository definitions);
```

**Чего эти задачи ждут от остальных, и кто это делает:**

- Тот, кто создаёт привычку-воздержание, пишет `committed_from` в
  `HabitDefinitions` и зовёт `attachDefinition(habit, definitions)` на живой
  привычке сразу после `DefinitionRepository.save` — иначе до перезапуска
  приложения её окно будет паритетным. Это **Задача 29** (`_AfterCommand.apply`).
- Тот, кто восстанавливает копию, прикрепляет определения к новым привычкам
  перед их `recompute()` — правило `computed.backup#2` про перенос дня
  обязательства уже есть, но перенос в базу и прикрепление к живой модели —
  разные вещи. Это **Задача 22**, шаг 8.
- Ячейка списка и экран привычки зовут ядровую `daysWithoutLapse(habit)` —
  своей копии в приложении нет, — а за датой начала
  `habit.streaks.getCurrent(getToday())?.start`. Это **Задача 36**.
- Обе стороны закрыты сквозным тестом **Задачи 43**: путь целиком, на одном
  файле базы, с перезапуском посередине.

### Task 19: журнал вешается на `AppScope` (1-schema.3, шаг 5)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/platform/first_run_foreign_keys_test.dart`

**Interfaces:**
- Потребляет: `LapseRepository` (Задача 3), `AppScope._` с уже поднятым
  `late final AppScope scope` (Задача 11) и с объявлением `definitions`,
  перенесённым выше цикла пересчёта (Задача 17).
- Даёт: поле `final LapseRepository lapses;` на `AppScope`.

Это отложенный шаг 5 задачи 1-schema.3. Он вынесен сюда, а не оставлен на месте,
по одной причине: `AppScope.open` правят три задачи, и текст хвоста этого метода
к моменту правки обязан быть уже тем, который привели Задача 11 и Задача 17.
Если повесить `lapses` раньше, приведённый в Задаче 11 дословный текст в файле не
найдётся, а слепое применение Задачи 17 даст второе объявление `definitions` в
той же области видимости — `Error: 'definitions' is already declared`.

- [ ] **Шаг 1: повесить репозиторий на AppScope**

В `app/lib/state/app_scope.dart`, в приватный конструктор `AppScope._`, после
`required this.definitions,`:

```dart
    required this.lapses,
```

после поля `final DefinitionRepository definitions;`:

```dart
  /// The journal an abstinence habit is scored from. See [LapseRepository].
  final LapseRepository lapses;
```

и в фабрике, рядом с объявлением `final definitions = DefinitionRepository(database);`:

```dart
    final lapses = LapseRepository(database);
```

плюс `lapses: lapses,` в вызов `AppScope._(`.

**Где именно рядом.** К этому моменту объявления `definitions` и `lapses` стоят
**выше цикла `for (final habit in habitList) { habit.recompute(); }`**, а не
перед `AppScope._(`: Задача 17 подняла `definitions` туда, потому что
`attachDefinitions` обязан отработать до первого пересчёта. В хвосте метода
остаётся только использование обоих имён в `AppScope._(`.

- [ ] **Шаг 2: каскад на настоящем соединении**

Схемный тест держит каскад на `openAppSchemaDatabase()`. Производственный путь —
`AppDatabase.openAndMigrate` — проверяется отдельно, и именно там
`computed.schema#2` уже стоит. Дописать в
`app/test/platform/first_run_foreign_keys_test.dart`, в тест
`'so deleting a habit on a first run takes its definition with it'`, перед
`scope.habitList.remove(habit);`:

```dart
    LapseRepository(db).save(habit.id!, 9000, amount: 45);
```

и после него, рядом с существующими проверками:

```dart
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.schema#5 — the lapse journal is on the same cascade');
```

- [ ] **Шаг 3: прогнать**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app
flutter test test/platform/first_run_foreign_keys_test.dart test/state/
```
Ожидается PASS: и каскад на настоящем соединении, и все соседние
`computed_*_test.dart`, которые открывают `AppScope`.

- [ ] **Шаг 4: мутация**

Убрать `lapses: lapses,` из вызова `AppScope._(` — файл перестанет собираться
(`The parameter 'lapses' is required`). Убрать строку
`LapseRepository(db).save(habit.id!, 9000, amount: 45);` из теста — проверка
каскада пройдёт, ничего не проверив; поэтому она и стоит первой, а сам тест
падает, если каскада нет. Возврат — обратной текстовой заменой.

- [ ] **Шаг 5: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add app
git commit -m "Hang the lapse journal on the application scope"
```

---

### Task 20: перечисление вычисляемых привычек по определению, а не по боковой таблице (6-hooks.1)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_archive_sweep_test.dart` (create)

**Interfaces:**
- Consumes: `DefinitionRepository.habitIdsOfKind(ComputedKind kind) → List<int>`,
  `SQLiteHabitList.getById(int id) → Habit?`, `Habit.isArchived → bool`.
- Produces: `Iterable<Habit> AppScope.computedHabits(ComputedKind kind)`.

Хук 1 сегодня наполовину есть: `_syncSleepHabits` пропускает архивные. Но
перечисляет он по `sleepRepository.sleepHabitIds()`, то есть по `SleepGoals` —
боковой таблице **сна**. У воздержания такой таблицы нет и не будет: его метка —
строка в `HabitDefinitions`. Пока перечисление сидит в боковой таблице, каждый
новый вид приносит свой цикл со своим фильтром — и второй забудет `isArchived`,
как забыл его первый.

**Шаги:**

1. Написать падающий тест. Создать
   `app/test/state/computed_archive_sweep_test.dart`:

```dart
/// `computed.lifecycle#4` — какие привычки вид вообще сводит.
///
/// Перечисление идёт по метке, а не по боковой таблице вида: у воздержания
/// боковой таблицы вроде `SleepGoals` нет, и цикл, написанный вокруг неё,
/// второму виду не достаётся. Фильтры — архив и исчезнувшая привычка — стоят
/// здесь, а не в каждом своде: правило, размазанное по видам, будет отнесено к
/// одним и не отнесено к другим.
library;

// Core models are reached by their `src` path, exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Database database;
  late AppScope scope;

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
  });

  tearDown(() {
    scope.close();
    resetToday();
  });

  Habit addHabit(String name) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = HabitType.numerical
      ..targetValue = 100
      ..unit = '%';
    scope.habitList.add(habit);
    return habit;
  }

  List<String> namesOf(ComputedKind kind) =>
      scope.computedHabits(kind).map((Habit h) => h.name).toList();

  test('a habit with the mark is enumerated', () {
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));

    expect(namesOf(ComputedKind.sleep), <String>['Sleep'],
        reason: 'computed.lifecycle#4');
  });

  test('a habit with a goal but no mark is not', () {
    // The mark is what makes a habit computed (`computed.definition#1`), so it
    // is also what says which sweep a habit belongs to. Enumerating out of
    // SleepGoals answers this one yes.
    final Habit habit = addHabit('Sleep');
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));

    expect(namesOf(ComputedKind.sleep), isEmpty,
        reason: 'computed.lifecycle#4');
  });

  test('an archived habit is not swept', () {
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.isArchived = true;
    scope.habitList.update(<Habit>[habit]);

    expect(namesOf(ComputedKind.sleep), isEmpty,
        reason: 'computed.lifecycle#4 — reading a platform for a habit the '
            'person put away is work nobody asked for');
  });

  test('another kind is not swept by this one', () {
    final Habit sleep = addHabit('Sleep');
    scope.definitions
        .save(sleep.id!, const HabitDefinition(kind: ComputedKind.sleep));
    final Habit quit = addHabit('No smoking');
    scope.definitions.save(
      quit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      ),
    );

    expect(namesOf(ComputedKind.sleep), <String>['Sleep'],
        reason: 'computed.lifecycle#4');
    expect(namesOf(ComputedKind.abstinence), <String>['No smoking'],
        reason: 'computed.lifecycle#4');
  });

  test('a mark whose habit is gone is skipped rather than crashed on', () {
    final Habit habit = addHabit('Sleep');
    final int id = habit.id!;
    scope.definitions.save(id, const HabitDefinition(kind: ComputedKind.sleep));
    // The row goes with the habit on the cascade, so this is the shape of the
    // race rather than of a leak: the ids are read, and the habit is removed
    // before the loop reaches it.
    scope.habitList.remove(habit);

    expect(scope.computedHabits(ComputedKind.sleep), isEmpty,
        reason: 'computed.lifecycle#4');
  });
}
```

2. Запустить, увидеть именованный провал:
   `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/state/computed_archive_sweep_test.dart`
   → `Error: The method 'computedHabits' isn't defined for the type 'AppScope'.`

3. Добавить метод в `app/lib/state/app_scope.dart`, сразу перед `syncSleepHabits`
   (то есть перед строкой `/// The sync currently running, so a second caller…`):

```dart
  /// Every habit of [kind] this device still has, and still works on.
  ///
  /// The enumeration goes through the mark rather than through the kind's own
  /// side table. `SleepGoals` answers "which habits are sleep habits" only
  /// because sleep happens to have such a table; abstinence has no equivalent
  /// and never will — its mark *is* the row in `HabitDefinitions`. A loop
  /// written around a side table is a loop the second kind cannot reuse.
  ///
  /// Both filters live here rather than in each kind's sweep. The ported
  /// scheduler and the tray already skip archived habits, and arming a
  /// question for one is a notification for a habit the person put away; a
  /// mark whose habit is gone is the shape of a teardown race, and reaching
  /// for it would be `getById(habitId)!`. A rule spread across the kinds is a
  /// rule that will be carried to some and not the rest
  /// (`computed.lifecycle#4`).
  ///
  /// Lazy on purpose: a sweep awaits a platform read between two habits, and
  /// the list can change under it. Each step asks the list again.
  Iterable<Habit> computedHabits(ComputedKind kind) sync* {
    for (final int id in definitions.habitIdsOfKind(kind)) {
      final Habit? habit = habitList.getById(id);
      if (habit == null) continue;
      if (habit.isArchived) continue;
      yield habit;
    }
  }
```

4. Запустить — тест зелёный.

5. Перевести свод сна на него. В `_syncSleepHabits` заменить

```dart
    for (final int id in sleepRepository.sleepHabitIds()) {
      final Habit? habit = habitList.getById(id);
      if (habit == null) continue;
      // The ported scheduler and tray both skip archived habits; reading the
      // platform for one is work nobody asked for, and arming its question is
      // a notification for a habit the person put away.
      if (habit.isArchived) continue;
```

   на

```dart
    for (final Habit habit in computedHabits(ComputedKind.sleep)) {
```

   Тело цикла не трогается вовсе: строку объявления (`onComputedDataChanged(id);`,
   бывшая `app_scope.dart:222`) Задача 11 уже удалила отсюда — объявляет дверь
   записи, — и переменной `id` в теле не осталось ни одной.

6. Прогнать соседей:
   `flutter test test/state/computed_archive_sweep_test.dart test/state/sleep_sync_wiring_test.dart test/state/sleep_freshness_test.dart test/state/computed_sleep_pairing_test.dart`

7. Дописать правило в `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`,
   в блок `computed.lifecycle`, четвёртым пунктом:

```
4. `computed.lifecycle#4` Свод вида перечисляет привычки по метке, а не по своей боковой таблице, и пропускает архивные и исчезнувшие.
```

8. `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && dart tool/parity_coverage.dart --verify` — зелёно.

9. Коммит: `hooks: enumerate computed habits by their mark`.

**Мутации, ломающие каждый тест:**
- убрать `if (habit.isArchived) continue;` → падает «an archived habit is not swept»;
- вернуть `definitions.habitIdsOfKind(kind)` → `sleepRepository.sleepHabitIds()`
  (и `getById`) → падает «a habit with a goal but no mark is not» и «another kind
  is not swept by this one»;
- убрать `if (habit == null) continue;` → падает «a mark whose habit is gone» с
  `Null check operator used on a null value`;
- заменить фильтр по `kind` на перечисление всех определений → падает «another
  kind is not swept by this one».

---

### Task 21: воздержание прицепляется к kind-blind хукам 2, 5, 6, 7 (6-hooks.4)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/computed_habit_hooks.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_habit_hooks_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/abstinence_hooks_test.dart` (create)

**Interfaces:**
- Produces: `ComputedHabitHooks({required void Function(Habit) withdrawAlarms})`
  (было `cancelPrompt`).
- Consumes: `AppScope.computedHabits` (6-hooks.1), `DefinitionRepository.isComputed`,
  `WidgetBehavior.setValue`, `ShowHabitMenuPresenter.onRandomize`, `DayWriter.write`.

Четыре хука из восьми написаны так, что вида не знают вовсе: `ComputedHabitHooks`
смотрит на команду, а не на определение; `WidgetBehavior.isComputed` и
`ShowHabitMenuPresenter._isComputed` спрашивают «есть ли строка», а не «какая»;
`DayWriter` про виды не слышал. Значит воздержание накрыто ими даром — но «даром»
без теста есть догадка. Здесь она становится проверенной, и заодно снимается
последнее сонное имя.

Отдельно закрепляется то, на чём держится третья запись отклонений («переключение
да/нет-привычки осталось без охраны»): она верна, пока ни одна вычисляемая
привычка не да/нет. Воздержание — числовая привычка `atMost` с целью 0; тест это
прибивает, и если кто-то заведёт вычисляемый вид как да/нет, тест упадёт раньше,
чем упадёт пользователь.

**Шаги:**

1. Написать падающий тест. Создать `app/test/state/abstinence_hooks_test.dart`:

```dart
/// Хуки, которые не смотрят на вид, — и воздержание под ними.
///
/// Четыре из восьми хуков слоя написаны через «есть ли у привычки определение»,
/// а не «какое». Значит второй вид получает их даром. Это и проверяется: даром
/// без теста есть догадка, а хуки закрывают потерю данных.
library;

// Commands and core models are reached by their `src` path, exactly as
// lib/state does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/computed_habit_hooks.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/state/widget_sync.dart' show WidgetBehavior;
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/computed/day_writer.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Постит в никуда: `WidgetBehavior` снимает уведомление на каждой записи, а
/// платформы, с которой его снимать, здесь нет. Форма взята дословно из
/// `app/test/state/computed_write_paths_test.dart:144`.
class _SilentTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database database;
  late AppScope scope;
  late Habit quit;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_hooks');
    database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
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
    scope.definitions.save(
      quit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      ),
    );
  });

  tearDown(() {
    scope.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    resetToday();
  });

  // Хук 2.
  test('deleting one withdraws its alarms, whatever kind it is', () {
    final List<int> withdrawn = <int>[];
    final ComputedHabitHooks hooks =
        ComputedHabitHooks(withdrawAlarms: (Habit h) => withdrawn.add(h.id!));

    hooks.onCommandFinished(DeleteHabitsCommand(scope.habitList, <Habit>[quit]));
    hooks.onCommandFinished(
        ArchiveHabitsCommand(scope.habitList, <Habit>[quit]));

    expect(withdrawn, <int>[quit.id!, quit.id!],
        reason: 'computed.lifecycle#5');
  });

  // Хук 5.
  test('a computed day keeps the note the person wrote', () {
    quit.originalEntries
        .add(Entry(LocalDate(9000), Entry.unknown, notes: 'третий день'));
    const DayWriter().write(quit, 9000, 500000);

    expect(quit.originalEntries.get(LocalDate(9000)).notes, 'третий день',
        reason: 'computed.day-write#1');
  });

  // Хук 6.
  test('the widget, the notification and the queue write nothing here', () {
    final WidgetBehavior behavior = WidgetBehavior(
      habitList: scope.habitList,
      commandRunner: scope.commandRunner,
      notificationTray: NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _SilentTray(),
      ),
      preferences: scope.preferences,
      isComputed: (int id) => scope.definitions.isComputed(id),
    );

    behavior.onAddRepetition(quit, LocalDate(9000));
    behavior.onToggleRepetition(quit, LocalDate(9000));
    behavior.onIncrement(quit, LocalDate(9000), 1000);

    expect(quit.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
        reason: 'computed.write-paths#1');
  });

  test('and it is numerical, so the unguarded yes/no toggle cannot reach it',
      () {
    // The one door with no guard is the yes/no toggle — a ported presenter
    // whose signature is closed by parity rules. It is out of reach only
    // while every computed habit is numerical, and this is where that stops
    // being a hope (см. DEVIATIONS.md, «переключение да/нет-привычки»).
    //
    // Страховка, а не доказательство: привычку выше построил числовой сам
    // тест, и при удалённой фиче эта строка останется зелёной. Настоящая
    // проверка правила — следующим тестом.
    expect(quit.isNumerical, isTrue, reason: 'computed.write-paths#5');
  });

  test('the kinds this build can create are numerical by construction', () {
    // Тип берётся у продакшна, а не у привычки, которую тест построил себе
    // сам, — этим он и отличается от страховки выше. `sleepHabitType` есть
    // константа, которой заводится сон (`sleep/stored_value.dart:68`);
    // воздержание заводится редактором, и его тип прибит там же, в наборе
    // Задачи 29, той же цитатой.
    //
    // Длина `ComputedKind.values` закреплена намеренно: третий вычисляемый вид
    // обязан пройти этой строкой и назвать свой тип, а не проскользнуть мимо
    // правила молча.
    expect(ComputedKind.values, hasLength(2),
        reason: 'computed.write-paths#5 — третий вид обязан пройти здесь');
    expect(sleepHabitType, HabitType.numerical,
        reason: 'computed.write-paths#5');
  });

  // Хук 7. Презентер строится тем же путём, которым его строит приложение —
  // через `ShowHabitModel`, как в `computed_guard_wiring_test.dart:62`, — а не
  // собирается тестом: у него шесть обязательных сотрудников, и собранный
  // вручную доказывал бы про себя, а не про экран.
  test('randomise does nothing at all', () {
    final ShowHabitModel model =
        ShowHabitModel(scope: scope, habit: quit, theme: LightTheme());
    addTearDown(model.dispose);
    quit.originalEntries.add(Entry(LocalDate(8999), 500000));

    model.menuPresenter.onRandomize();

    expect(quit.originalEntries.get(LocalDate(8999)).value, 500000,
        reason: 'computed.lifecycle#3 — originalEntries.clear() is '
            'deleteByHabitId, and it would take the journal with it');
  });
}
```

   Импорты для этого теста: `package:uhabits/state/show_habit_model.dart` вместо
   `src/ui/screens/habits/show/show_habit_menu_presenter.dart`, плюс тема —
   ровно тот же набор, что у `computed_guard_wiring_test.dart`.

2. Запустить:
   `cd .../app && flutter test test/state/abstinence_hooks_test.dart`
   → `Error: No named parameter with the name 'withdrawAlarms'.`

3. Переименовать в `app/lib/state/computed_habit_hooks.dart`:

```dart
class ComputedHabitHooks implements CommandRunnerListener {
  ComputedHabitHooks({required void Function(Habit) withdrawAlarms})
      : _withdrawAlarms = withdrawAlarms;

  final void Function(Habit) _withdrawAlarms;
```

   и в теле `onCommandFinished`: `_cancelPrompt(habit)` → `_withdrawAlarms(habit)`.
   В доке класса заменить «a question armed with the system» на видонезависимое:

```dart
/// The lifecycle a computed habit has and a ported one does not.
///
/// A habit whose day value the app computes owns things outside the habit
/// list: alarms armed with the system, rows in tables of its own. Nothing in
/// the ported command layer knows they exist, so a deleted habit used to leave
/// its alarm standing — and an alarm that fires for a habit that is gone walks
/// into `getById(habitId)!`.
///
/// Kind-blind on purpose, and that is the whole of hook 2 for every kind after
/// the first: withdrawing an alarm that was never armed costs a no-op, while
/// asking "which kind is this" would put the second kind's name in a file that
/// has no business knowing it (`computed.lifecycle#5`).
```

4. Поправить единственную площадку сборки — `app/lib/state/app_scope.dart`,
   в `startServices`:

```dart
    // Withdraws whatever a computed habit armed with the system when the habit
    // goes away. Held so that close() can take it off again.
    _computedHooks = ComputedHabitHooks(
      withdrawAlarms: (Habit habit) =>
          unawaited(sleepPrompts?.cancel(habit) ?? Future<void>.value()),
    );
```

5. Поправить существующий `app/test/state/computed_habit_hooks_test.dart`:
   `cancelPrompt:` → `withdrawAlarms:`.

6. Прогнать:
   `flutter test test/state/abstinence_hooks_test.dart test/state/computed_habit_hooks_test.dart test/state/computed_guard_wiring_test.dart test/state/computed_write_paths_test.dart`

7. Дописать правила в `docs/extensions/COMPUTED.md`:
   - в блок `computed.lifecycle`:
```
5. `computed.lifecycle#5` Удаление и архивация снимают будильники вычисляемой привычки любого вида, а не только сна.
```
   - в блок `computed.write-paths`:
```
5. `computed.write-paths#5` Вычисляемая привычка — числовая; неохраняемое переключение да/нет её не достаёт.
```

8. `dart tool/parity_coverage.dart --verify`, коммит:
   `hooks: attach abstinence to the kind-blind hooks`.

**Мутации:**
- в `ComputedHabitHooks.onCommandFinished` заменить `ArchiveHabitsCommand(...)` на
  `_ => const <Habit>[]` → падает «deleting one withdraws its alarms»
  (`withdrawn` = `[id]`);
- убрать `notes: existing.notes` в `DayWriter.write` → падает «a computed day
  keeps the note»;
- убрать `if (id != null && isComputed(id)) return;` в `WidgetBehavior.setValue`
  → падает «the widget, the notification and the queue write nothing here»;
- убрать `if (id != null && (_isComputed?.call(id) ?? false)) return;` в
  `onRandomize` → падает «randomise does nothing at all»;
- задать привычке `type = HabitType.yesNo` → падает «and it is numerical» и,
  следом, третья запись отклонений перестаёт быть верной — что и есть смысл
  этого теста;
- `const HabitType sleepHabitType = HabitType.numerical;` → `= HabitType.yesNo;`
  (`sleep/stored_value.dart:68`) → падает «the kinds this build can create are
  numerical by construction», и падает у **продакшн**-константы, а не у
  тестовой привычки;
- завести третью запись в `ComputedKind` → падает он же на `hasLength(2)`.

**Что из этого страховка, а что доказательство.** Тест «and it is numerical, so
the unguarded yes/no toggle cannot reach it» зелен и при **удалённой** фиче: он
утверждает отсутствие — «привычка числовая», — а привычку эту построил числовой
сам тест. Убрать из `lib/` всё воздержание целиком, и он останется зелёным.
Выбрасывать его не надо: он падает в тот день, когда кто-нибудь заведёт
вычисляемый вид как да/нет. Но закрывать им правило `computed.write-paths#5`
нельзя — правило держалось бы на утверждении, которое ничего не проверяет.
Поэтому у `#5` есть вторая цитата, настоящая: «the kinds this build can create
are numerical by construction» здесь и `expect(habit.type, HabitType.numerical)`
в наборе Задачи 29, где привычку строит редактор, а не тест.

---

### Task 22: хук 3 — журнал срывов переживает восстановление копии (6-hooks.5)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_importer.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/io/loop_db_importer.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/settings/data_actions.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_guard_wiring_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/io/lapse_import_test.dart` (create)

**Interfaces:**
- Produces: `class LapseImporter { const LapseImporter(LapseRepository destination); void importFor(Database source, int? sourceHabitId, int destinationHabitId); }`
- Produces: поле `final LapseImporter? lapseImporter;` в `LoopDBImporter` и
  именованный параметр `this.lapseImporter` в его конструкторе.
- Consumes (Задача 3): `LapseRepository(Database db)`,
  `int? LapseRepository.firstDay(int habitId)`, `int? LapseRepository.lastDay(int habitId)`,
  `Map<int, int> LapseRepository.range(int habitId, int fromDay, int toDay)`,
  `void LapseRepository.save(int habitId, int day, {int amount = minimumAmount})`
  — именно `save`, а не `upsert`: он единственный несёт охрану
  `amount >= minimumAmount` (`computed.lapses#2`) и умолчание «один тап = одна
  единица», а три позиционных инта эту охрану теряют.
- Consumes: `attachDefinitions` (Задача 17) — для шага 8.

Копия — побайтовый файл, и строки `Lapses` в нём есть всегда. Теряет их импорт:
привычки матчатся по uuid и получают свободный на этом устройстве id, а строки
журнала лежат под id **чужого** устройства. Ровно та же потеря, ради которой
написаны `SleepImporter` и `DefinitionImporter`; третий сотрудник того же вида.
Что `committed_from` переезжает, уже закрыто (`computed.backup#2`) — а без журнала
день обязательства вернётся, а сорок дней между ним и первым срывом нет.

**Шаги:**

1. Написать падающий тест. Создать
   `packages/uhabits_core/test/io/lapse_import_test.dart`, взяв каркас
   (`buildImporter`, `importFile`, временный файл-источник) целиком из соседнего
   `packages/uhabits_core/test/io/definition_import_test.dart` и заменив в нём
   предмет:

```dart
  test('a restored habit comes back with its journal', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source)
      ..save(41, 8990, amount: 1)
      ..save(41, 8997, amount: 3);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).range(restored.id!, 8990, 8997),
        <int, int>{8990: 1, 8997: 3},
        reason: 'computed.backup#4');
  });

  test('the amount travels, not just the day', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 30);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).range(restored.id!, 8990, 8990)[8990], 30,
        reason: 'computed.backup#4 — «не более 30 минут» есть допуск, и '
            'потерянная величина превращает срыв в другой срыв');
  });

  test('a habit with no journal is answered silently', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).firstDay(restored.id!), isNull,
        reason: 'computed.backup#4 — это почти каждая привычка');
  });

  test('an importer with no journal to write to behaves as upstream',
      () async {
    // Null вместо сотрудника — это каждый тест импорта, написанный до этой
    // задачи, и они обязаны продолжать проходить без правки.
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 1);
    source.close();

    await buildImporter(lapseImporter: null).importHabitsFromFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).firstDay(restored.id!), isNull,
        reason: 'computed.backup#4 — the employee is optional');
  });
```

2. Запустить:
   `cd .../packages/uhabits_core && dart test test/io/lapse_import_test.dart`
   → `Error: Couldn't find constructor 'LapseImporter'.`

3. Создать `packages/uhabits_core/lib/src/computed/lapse_importer.dart`:

```dart
import '../database/database.dart';
import 'lapse_repository.dart';

/// Carries an abstinence habit's journal of lapses across a restore.
///
/// A backup is a byte-for-byte copy, so the rows are always in the file. What
/// loses them is the import: habits are matched by uuid and given whatever id
/// this device has free, while every lapse is filed under the id the *other*
/// device used. Nothing rewrites those, so without this the restored habit
/// comes back with its commitment day and an empty history behind it — which
/// reads as a clean run since the day it was made, and is the most flattering
/// possible lie.
///
/// Reads go through a [LapseRepository] pointed at the source file rather than
/// through SQL of its own, exactly as `SleepImporter` does: the schema is
/// stated once, and a column added to it cannot be forgotten here.
class LapseImporter {
  const LapseImporter(this._destination);

  final LapseRepository _destination;

  /// Moves every lapse belonging to [sourceHabitId] in [source] onto
  /// [destinationHabitId] here.
  ///
  /// Answers silently for a habit that has no journal, which is nearly all of
  /// them.
  void importFor(Database source, int? sourceHabitId, int destinationHabitId) {
    if (sourceHabitId == null) return;
    final LapseRepository origin = LapseRepository(source);

    final int? from = origin.firstDay(sourceHabitId);
    final int? to = origin.lastDay(sourceHabitId);
    if (from == null || to == null) return;

    for (final MapEntry<int, int> lapse
        in origin.range(sourceHabitId, from, to).entries) {
      _destination.save(destinationHabitId, lapse.key, amount: lapse.value);
    }
  }
}
```

4. Подключить к импортёру. В
   `packages/uhabits_core/lib/src/io/loop_db_importer.dart`:
   - `import 'package:.../computed/lapse_importer.dart';` (относительный
     `../computed/lapse_importer.dart`, как соседний `definition_importer`);
   - в конструктор, после `this.definitionImporter,`, добавить
     `this.lapseImporter,`;
   - поле рядом с `definitionImporter`:

```dart
  /// Not upstream, and for the same reason as [sleepImporter]: an abstinence
  /// habit's journal is keyed by habit id, and the ids here are not the ids
  /// the file was written with.
  final LapseImporter? lapseImporter;
```

   - в цикле, сразу после `definitionImporter?.importFor(db, habitData.id, habit.id!);`:

```dart
      lapseImporter?.importFor(db, habitData.id, habit.id!);
```

5. Экспортировать из бочки: в `packages/uhabits_core/lib/uhabits_core.dart`, рядом
   с `export 'src/computed/definition_repository.dart';`, добавить
   `export 'src/computed/lapse_importer.dart';`.

6. Прогнать тест — зелено. Затем `dart test test/io/`.

7. Проводка приложения. В
   `app/lib/ui/settings/data_actions.dart`, в `buildGenericImporter`, после
   `definitionImporter: DefinitionImporter(scope.definitions),` добавить

```dart
    lapseImporter: LapseImporter(scope.lapses),
```

   (`scope.lapses` — поле `LapseRepository` на `AppScope` из секции журнала
   срывов). Импорт: `import 'package:uhabits_core/src/computed/lapse_importer.dart';`
   рядом с уже имеющимся `definition_importer.dart`.

8. Прикрепить определения после восстановления — и закрыть проводку **сквозным**
   тестом.

   `DefinitionImporter` и `LapseImporter` пишут в базу; `LoopDBImporter` затем
   зовёт `habit.recompute()` на привычках, у которых `definition == null`. Сорок
   дней и деление пополам вернулись бы только после перезапуска. В
   `app/lib/ui/settings/data_actions.dart`, в обработчике завершения импорта —
   там же, где список перечитывается, — позвать:

```dart
      attachDefinitions(scope.habitList, scope.definitions);
      for (final Habit habit in scope.habitList) {
        habit.recompute();
      }
```

   Тест — в `app/test/state/computed_guard_wiring_test.dart`, там уже стоит ровно
   эта мысль: «guard'ы на экземплярах, и стоят они ровно столько, сколько их
   проводка». Проверка «`buildGenericImporter` вернул не-null» тестом не
   является: она зелена и без строки `lapseImporter:`. Поэтому — сквозной:

```dart
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
    // `userDataDir` у опенера обязателен и в тесте, и в продакшне. В продакшне
    // это `directories.filesDir` — `app/lib/ui/settings/data_actions.dart:138`,
    // `FlutterFileOpener(userDataDir: directories.filesDir)`; здесь тот же
    // временный каталог, в котором лежит копия.
    await buildGenericImporter(
      scope: scope,
      fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
    ).importHabitsFromFile(file);

    final Habit restored = scope.habitList.getByUUID('abst-uuid')!;
    expect(scope.lapses.range(restored.id!, 8990, 9007),
        <int, int>{8990: 1, 9000: 45, 9007: 12},
        reason: 'computed.backup#4 — без проводки восстановление молча '
            'возвращает чистую историю, которой не было');
    expect(restored.definition?.committedFrom, isNotNull,
        reason: 'computed.commitment#5 — строка в базе и живая модель разные '
            'вещи: пересчёт читает поле, а не репозиторий');
    expect(restored.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11');
  });
```

   Тело `backupWithLapses` выписано выше целиком и намеренно: «копия» здесь
   значит побайтовый файл базы, а не выгрузку, и подменить его сборкой в памяти
   нельзя — вопрос ровно в том, переживают ли строки настоящий файл. Три дня
   журнала (`8990: 1`, `9000: 45`, `9007: 12`) — те же, что в проверке ниже.
   Импорты, которых требует это тело: `dart:io` (ради `File`),
   `package:uhabits/platform/app_database.dart`,
   `package:uhabits/platform/flutter_files.dart` (`FlutterFileOpener`) и
   `package:uhabits_core/uhabits_core.dart` (`LocalUserFile`,
   `DefinitionRepository`, `LapseRepository`, `HabitDefinition`).

9. Правило в `docs/extensions/COMPUTED.md`, в блок `computed.backup`:

```
4. `computed.backup#4` Восстановление копии переносит журнал срывов на привычку с тем же uuid, вместе с величиной каждого срыва.
```

10. `dart tool/parity_coverage.dart --verify`, коммит:
    `hooks: carry the lapse journal across a restore`.

**Мутации:**
- убрать `lapseImporter?.importFor(...)` из цикла `LoopDBImporter` → падает «a
  restored habit comes back with its journal»;
- в `LapseImporter.importFor` писать `_destination.save(destinationHabitId,
  lapse.key)` вместо `amount: lapse.value` → падает «the amount travels, not
  just the day»: 8990 вернёт 1 вместо 30;
- убрать `if (from == null || to == null) return;` → падает «a habit with no
  journal is answered silently» (исключение при `range(id, null, null)`);
- убрать строку `lapseImporter:` из `buildGenericImporter` → падает сквозной
  тест приложения из шага 8 на `scope.lapses.range(...)`;
- убрать `attachDefinitions(scope.habitList, scope.definitions);` из обработчика
  импорта → падает он же, на `restored.definition?.committedFrom` и на
  `halvesOnLapse`.

---

### Task 23: после удаления не остаётся ничего — на настоящем файле базы (6-hooks.6)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/abstinence_teardown_test.dart` (create)

**Interfaces:**
- Consumes: `AppDatabase.openAndMigrate(String path) → Database`, `AppScope.open`,
  `SQLiteHabitList.remove/update`, `DefinitionRepository`, `LapseRepository`.
- Produces: ничего в коде. Задача — доказательство; кода она добавляет только
  если доказательство провалилось.

**Что должно быть верно, чтобы после удаления не осталось ничего:**

1. `Lapses.habit` объявлен `references Habits(id) on delete cascade` в миграции
   103 — как `HabitDefinitions.habit` в 102. Составной первичный ключ
   `(habit, day)` каскаду не мешает.
2. `pragma foreign_keys` включён на том соединении, которое реально открывает
   приложение. Это уже доказано
   `app/test/platform/first_run_foreign_keys_test.dart`; здесь на этом стоят.
3. Ни один параметр воздержания не живёт в `Preferences` под ключом с
   идентификатором привычки. У сна таких два — `sleep.travelPromptDismissed.$id`
   и `sleep.goalSuggestionDismissed.$id` (`app_scope.dart:122`, `:143`), и они
   переживают удаление. Воздержанию это запрещено: допуск и единица лежат в
   `HabitDefinitions.payload`, день обязательства — в `committed_from`, срывы — в
   `Lapses`; все три на каскаде. Правило важнее опрятности: `Habits.id` есть
   `integer primary key autoincrement`, id не переиспользуются, — но ключ
   настроек переживает и переустановку вида, и восстановление копии.
4. Будильник снят: хук 2 (6-hooks.4). У воздержания по умолчанию будильника нет,
   но включённый вечерний вопрос обязан сниматься тем же путём.
5. Архивация не удаляет **ничего**: она обратима, и разархивированная привычка
   обязана вернуться со своим журналом и днём обязательства.

Проверка формулируется не через список таблиц, а через вопрос к самой базе:
«есть ли где-нибудь строка с этим habit id». Так тест переживёт появление
четвёртой таблицы вида, чего список бы не пережил.

**Шаги:**

1. Написать падающий тест. Создать `app/test/state/abstinence_teardown_test.dart`:

```dart
/// `computed.lifecycle#6`, `#7` — что остаётся от привычки-воздержания после
/// удаления, и что обязано остаться после архивации.
///
/// На настоящем файле, а не на `Sqlite3Database.memory()`: каскад держится на
/// `pragma foreign_keys`, а это настройка соединения, и вопрос стоит ровно к
/// тому соединению, которое открывает приложение
/// (см. `app/test/platform/first_run_foreign_keys_test.dart`).
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database database;
  late AppScope scope;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_gone');
    database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    resetToday();
  });

  Habit abstinenceHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'No smoking'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
        payload: <String, Object?>{'allowance': 30.0, 'unit': 'minutes'},
      ),
    );
    scope.lapses.save(habit.id!, 8990, amount: 45);
    habit.originalEntries.add(Entry(LocalDate(8990), 500000));
    habit.recompute();
    return habit;
  }

  /// Every table in this file that files rows under a habit id.
  ///
  /// Asked of the schema rather than listed by hand: a kind added later brings
  /// a table of its own, and a hand-written list is a list that will not have
  /// been updated.
  List<String> tablesKeyedByHabit() {
    final List<String> tables = <String>[];
    database.query(
      "select name from sqlite_master where type = 'table' "
      "and name not like 'sqlite_%'",
      const <String>[],
      (stmt) => tables.add(stmt.getText(0)),
    );
    return tables.where((String table) {
      var found = false;
      database.query('pragma table_info($table)', const <String>[], (stmt) {
        if (stmt.getText(1).toLowerCase() == 'habit') found = true;
      });
      return found;
    }).toList();
  }

  List<String> tablesStillHolding(int habitId) => tablesKeyedByHabit()
      .where((String table) =>
          database.queryInt('select count(*) from $table where habit = $habitId') >
          0)
      .toList();

  test('the file has more than one table keyed by habit', () {
    // Guards the guard: a query that finds nothing to look at passes every
    // assertion below without asking anything.
    expect(tablesKeyedByHabit(),
        containsAll(<String>['Repetitions', 'HabitDefinitions', 'Lapses']),
        reason: 'computed.lifecycle#6');
  });

  test('deleting one leaves no row anywhere', () {
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;
    expect(tablesStillHolding(id), isNotEmpty,
        reason: 'computed.lifecycle#6 — there has to be something to lose');

    scope.habitList.remove(habit);

    expect(tablesStillHolding(id), isEmpty,
        reason: 'computed.lifecycle#6 — a row left behind is a row the next '
            'habit at this id would inherit');
    expect(database.queryInt('select count(*) from Habits where id = $id'), 0,
        reason: 'computed.lifecycle#6');
  });

  test('and nothing of it is kept in preferences under its id', () {
    // The kind's parameters live in `HabitDefinitions.payload` and its lapses
    // in `Lapses`, both on the cascade. A preferences key would outlive the
    // habit, the restore and the reinstall, and nothing would ever collect it.
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;
    scope.habitList.remove(habit);

    for (final String key in <String>[
      'abstinence.allowance.$id',
      'abstinence.committedFrom.$id',
      'abstinence.promptDismissed.$id',
    ]) {
      expect(scope.preferencesStorage.getString(key, ''), '',
          reason: 'computed.lifecycle#6 — the kind keeps nothing in '
              'preferences keyed by habit id');
    }
  });

  test('archiving keeps everything, and un-archiving gives it all back', () {
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;

    habit.isArchived = true;
    scope.habitList.update(<Habit>[habit]);

    expect(scope.lapses.range(id, 8990, 8990), <int, int>{8990: 45},
        reason: 'computed.lifecycle#7 — archiving is reversible, so it '
            'destroys nothing');
    expect(scope.definitions.forHabit(id)?.committedFrom, 8960,
        reason: 'computed.lifecycle#7');

    habit.isArchived = false;
    scope.habitList.update(<Habit>[habit]);

    expect(scope.definitions.forHabit(id)?.payload['allowance'], 30.0,
        reason: 'computed.lifecycle#7 — the day of the commitment and the '
            'allowance come back with it, or forty clean days did not happen');
  });
}
```

2. Запустить:
   `cd .../app && flutter test test/state/abstinence_teardown_test.dart`
   Ожидаемый провал до миграции 103 — на первом тесте:
   `Expected: contains all of ['Repetitions', 'HabitDefinitions', 'Lapses']`.
   После того как секция журнала срывов создала таблицу, но забыла каскад,
   провалится «deleting one leaves no row anywhere»:
   `Expected: isEmpty  Actual: ['Lapses']`.

3. Каскад обязан **уже стоять**: его пишет Задача 1, и там же он проверен на
   DDL. Эта задача его не добавляет — она спрашивает у настоящего файла базы,
   работает ли он на том соединении, которое открывает приложение, и сразу про
   **все** таблицы, а не про одну. Если «deleting one leaves no row anywhere»
   падает с `Actual: ['Lapses']` — чинить в Задаче 1, в скрипте 103
   (`habit integer not null references Habits(id) on delete cascade`), а не
   здесь.

4. Прогнать снова — зелено. Затем весь набор состояния:
   `flutter test test/state/`

5. Правила в `docs/extensions/COMPUTED.md`, в блок `computed.lifecycle`:

```
6. `computed.lifecycle#6` Удаление привычки не оставляет ни одной строки под её идентификатором ни в одной таблице и ни одного ключа настроек с ним.
7. `computed.lifecycle#7` Архивация не удаляет ничего: разархивированная привычка возвращается со своим журналом, днём обязательства и параметрами вида.
```

6. `dart tool/parity_coverage.dart --verify`, коммит:
   `hooks: a deleted abstinence habit leaves nothing behind`.

**Мутации:**
- убрать `references Habits(id) on delete cascade` из миграции 103 → падает
  «deleting one leaves no row anywhere» с `Actual: ['Lapses']`;
- то же убрать из миграции 102 → падает он же, с `['HabitDefinitions']`;
- выполнить `database.run('pragma foreign_keys=OFF')` в `setUp` → падает он же,
  сразу обеими таблицами;
- заменить `tablesKeyedByHabit()` на жёсткий список `['Lapses']` → падает «the
  file has more than one table keyed by habit»;
- в `abstinenceHabit()` записать допуск в
  `scope.preferencesStorage.putInt('abstinence.allowance.${habit.id}', 30)`
  вместо `payload` → падает «and nothing of it is kept in preferences under its
  id»;
- заменить в `habitList.update` архивацию на `habitList.remove` → падает
  «archiving keeps everything».

**Что из этого страховка, а что доказательство.** Тест «and nothing of it is kept
in preferences under its id» зелен и при **удалённой** фиче: он утверждает
отсутствие ключей, а отсутствуют они и тогда, когда воздержания в `lib/` нет
вовсе. Выбрасывать его не надо — он падает в тот день, когда кто-нибудь положит
допуск или «подсказку, которую закрыли» в `Preferences` под `$habitId`, как это
уже сделано у сна двумя ключами. Но правило `computed.lifecycle#6` им **не**
закрывается: настоящая его цитата — «deleting one leaves no row anywhere», где
строки сперва пишутся, потом ищутся и не находятся, и где страховкой служит
отдельный тест «the file has more than one table keyed by habit».

---

### Task 24: `AbstinenceSync` — свод воздержания (6-hooks.8)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_sync.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/app_scope.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/computed/abstinence_sync_test.dart`

**Interfaces:**
- Потребляет: `LapseRepository` (Задача 3), `lapseDayValue` (Задача 5),
  `DayWriter.writeDays` и `DayWriter.clear` (Задача 11), `HabitDefinition`.
- Даёт:

```dart
class AbstinenceSync {
  AbstinenceSync({required LapseRepository lapses, required DayWriter writer});
  void setLapse(Habit habit, LocalDate date, bool lapsed, {int? amount});
  bool recomputeDays(Habit habit, int fromDay, int toDay);
  bool recomputeAll(Habit habit, HabitDefinition definition);
}
```

- и поле `final AbstinenceSync abstinence;` на `AppScope`.

**Зачем эта задача существует.** `LapseRepository` пишет журнал, `DayWriter`
пишет день, и до этой задачи их не соединяет никто: тап по ячейке приходит в
пустоту. Арифметика дня принадлежит ядру, а не UI, — потому класс живёт в
`packages/uhabits_core/lib/src/computed/`, а не в `app/lib/ui/`. Это ровно та же
четвёрка ролей, что у сна («Конвейер» спецификации): источник — палец человека,
хранилище — [LapseRepository], определение — `lapseDayValue` с допуском из
`HabitDefinition`, свод — этот класс.

- [ ] **Шаг 1: написать падающий тест**

Создать `packages/uhabits_core/test/computed/abstinence_sync_test.dart`. Каждый
тест — с мутацией из шага 6:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/abstinence_sync.dart';
import 'package:uhabits_core/src/computed/day_writer.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late LapseRepository lapses;
  late AbstinenceSync sync;
  late Habit habit;
  late LocalDate today;

  setUp(() {
    setToday(LocalDate(9000));
    today = getToday();
    db = openAppSchemaDatabase();
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    lapses = LapseRepository(db);
    sync = AbstinenceSync(lapses: lapses, writer: const DayWriter());
    habit = MemoryModelFactory().buildHabit()
      ..id = 1
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..definition = const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
      );
  });

  tearDown(() {
    db.close();
    resetToday();
  });

  test('a second tap on the same day is still one lapse', () {
    sync.setLapse(habit, today, true);
    sync.setLapse(habit, today, true);

    expect(db.queryInt('select count(*) from Lapses'), 1,
        reason: 'computed.abstinence-sync#1');
    expect(habit.originalEntries.get(today).value, 1000,
        reason: 'computed.abstinence-sync#1 — журнал и день сходятся');
  });

  test('taking it back returns the day to silence', () {
    sync.setLapse(habit, today, true);
    sync.setLapse(habit, today, false);

    expect(lapses.forDay(1, today.daysSince2000), isNull,
        reason: 'computed.abstinence-sync#2');
    expect(habit.originalEntries.get(today).value, Entry.unknown,
        reason: 'computed.abstinence-sync#2 — иначе вчерашние 45000 остаются '
            'лежать в дне, который человек только что отменил');
  });

  test('a recompute covers the range, not the day', () {
    lapses.save(1, 8990, amount: 1);
    sync.recomputeDays(habit, 8985, 8995);

    expect(habit.originalEntries.get(LocalDate(8990)).value, 1000,
        reason: 'computed.abstinence-sync#3');
    for (final int day in <int>[8985, 8991, 8995]) {
      expect(habit.originalEntries.get(LocalDate(day)).value, Entry.unknown,
          reason: 'computed.abstinence-sync#3 — чистый день не пишется вовсе, '
              'иначе в диапазоне появятся десять срывов');
    }
  });

  test('the sweep does not touch a skip', () {
    habit.originalEntries.add(Entry(today, Entry.skip));
    sync.setLapse(habit, today, true);

    expect(habit.originalEntries.get(today).value, Entry.skip,
        reason: 'computed.abstinence-sync#4 — пропуск есть отметка человека '
            '(`computed.day-write#4`)');
  });

  test('the whole commitment is rescored from its first day', () {
    lapses.save(1, 8961, amount: 45);
    final bool wrote = sync.recomputeAll(
      habit,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
      ),
    );

    expect(wrote, isTrue, reason: 'computed.abstinence-sync#5');
    expect(habit.originalEntries.get(LocalDate(8961)).value, 45000,
        reason: 'computed.abstinence-sync#5 — понижение допуска обязано '
            'переоценить уже записанные дни (`computed.allowance#1`)');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/computed/abstinence_sync_test.dart
```
Ожидается FAIL: `Error: ... abstinence_sync.dart ... doesn't exist`.

- [ ] **Шаг 3: написать свод**

Создать `packages/uhabits_core/lib/src/computed/abstinence_sync.dart`:

```dart
import '../models/habit.dart';
import '../time/local_date.dart';
import 'day_writer.dart';
import 'habit_definition.dart';
import 'lapse_day_value.dart';
import 'lapse_repository.dart';

/// Свод воздержания: журнал срывов → значения дней.
///
/// Ровно та же четвёрка ролей, что у сна («Конвейер» спецификации): источник —
/// палец человека, хранилище — [LapseRepository], определение —
/// [lapseDayValue] с допуском из [HabitDefinition], свод — этот класс.
/// Считает по диапазону, а не по дню: у «дней без срыва» балл дня зависит от
/// прошлого ровно так же, как у свёртки часового пояса во сне.
class AbstinenceSync {
  AbstinenceSync({required this.lapses, required this.writer});

  final LapseRepository lapses;

  /// Единственная дверь записи. Она же — та, что пересчитывает привычку и один
  /// раз объявляет об изменении: в приложении сюда приходит `DayWriter`,
  /// собранный с тем же `onChanged`, что и у сна (`computed.freshness#2`).
  final DayWriter writer;

  /// Записывает или снимает срыв за [date] и пересчитывает день.
  ///
  /// Идемпотентно: повторный `setLapse(h, d, true)` даёт один срыв — журнал
  /// заменяет строку (`computed.lapses#3`), а [DayWriter] не переписывает
  /// неизменившееся значение (`computed.day-write#5`).
  ///
  /// Снятие идёт не через запись null: `writeDays` на null означает «сказать
  /// нечего» и оставляет запись как была (`computed.day-write#3`). Здесь
  /// сказано другое — «того, что было записано, не было», — и это [DayWriter.clear]
  /// (`computed.day-write#8`).
  void setLapse(Habit habit, LocalDate date, bool lapsed, {int? amount}) {
    final int id = habit.id!;
    final int day = date.daysSince2000;
    if (lapsed) {
      lapses.save(id, day, amount: amount ?? LapseRepository.minimumAmount);
      recomputeDays(habit, day, day);
    } else {
      lapses.remove(id, day);
      writer.clear(habit, day);
    }
  }

  /// Пересчитывает дни `[fromDay, toDay]` из журнала.
  ///
  /// Зовётся и при смене допуска: понижение с 30 до 10 обязано переоценить уже
  /// записанные дни (`computed.allowance#1`), а значение дня есть величина, и
  /// от допуска не зависит — зависит от него ветвь деления пополам, поэтому
  /// пересчёт нужен весь.
  bool recomputeDays(Habit habit, int fromDay, int toDay) {
    final int id = habit.id!;
    final Map<int, int> journal = lapses.range(id, fromDay, toDay);
    final Map<int, int?> values = <int, int?>{};
    for (int day = fromDay; day <= toDay; day++) {
      values[day] = lapseDayValue(journal[day] ?? 0);
    }
    return writer.writeDays(habit, values);
  }

  /// Весь диапазон обязательства — от `committedFrom` до сегодня.
  bool recomputeAll(Habit habit, HabitDefinition definition) {
    final int? from = definition.committedFrom;
    if (from == null) return false;
    return recomputeDays(habit, from, getToday().daysSince2000);
  }
}
```

Дописать в `packages/uhabits_core/lib/uhabits_core.dart`, в блок
`// Computed habits`:

```dart
export 'src/computed/abstinence_sync.dart';
```

- [ ] **Шаг 4: повесить свод на `AppScope`**

В `app/lib/state/app_scope.dart`, рядом с полем `final LapseRepository lapses;`
(Задача 19):

```dart
  /// Журнал срывов → значения дней. См. [AbstinenceSync].
  final AbstinenceSync abstinence;
```

и `required this.abstinence,` в приватный конструктор. В `AppScope.open` свод
собирается **тем же объявляющим `DayWriter`**, что и `SleepSync` (Задача 11,
шаг 7), — то есть внутри того же вызова `AppScope._(`:

```dart
      abstinence: AbstinenceSync(
        lapses: lapses,
        // Тот же объявляющий писатель, что у сна: тогда объявление списку идёт
        // даром, привычка пересчитывается до объявления
        // (`computed.freshness#4`), и жесту UI не нужно звать
        // `onComputedDataChanged` вторым вызовом.
        writer: DayWriter(
          onChanged: (int habitId) => scope.onComputedDataChanged(habitId),
        ),
      ),
```

- [ ] **Шаг 5: запустить**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core && dart test test/computed/
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/state/
```
Ожидается PASS.

- [ ] **Шаг 6: мутации**

| Мутация | Что обязано упасть |
|---|---|
| в `LapseRepository.save` заменить `on conflict(habit, day) do update ...` на `insert` без `on conflict` | «a second tap on the same day is still one lapse» — вторая вставка бросит `UNIQUE constraint failed` |
| в `setLapse`, ветвь `false`: `writer.clear(habit, day)` → `recomputeDays(habit, day, day)` | «taking it back returns the day to silence» — в дне остаётся прежнее значение |
| `values[day] = lapseDayValue(journal[day] ?? 0);` → `?? 1` | «a recompute covers the range, not the day» — в диапазоне появятся одиннадцать срывов |
| писать в `habit.originalEntries` напрямую, минуя `DayWriter` | «the sweep does not touch a skip» |
| в `recomputeAll` заменить `definition.committedFrom` на `getToday().daysSince2000` | «the whole commitment is rescored from its first day» |

- [ ] **Шаг 7: записать правила**

В `docs/extensions/COMPUTED.md` добавить блок после `computed.lapses`:

```markdown
- [x] `computed.abstinence-sync`
1. `computed.abstinence-sync#1` Повторный срыв за тот же день идемпотентен: одна строка журнала и одно значение дня.
2. `computed.abstinence-sync#2` Отмена срыва возвращает день в молчание, а не оставляет в нём вчерашнюю величину.
3. `computed.abstinence-sync#3` Пересчёт идёт по диапазону и не пишет нулей в чистые дни.
4. `computed.abstinence-sync#4` Свод не трогает пропуск.
5. `computed.abstinence-sync#5` Смена допуска пересчитывает всё обязательство — от его дня до сегодня.
```

- [ ] **Шаг 8: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add packages/uhabits_core app ../docs/extensions/COMPUTED.md
git commit -m "Join the lapse journal to the day values it produces"
```

---

## Раздел «Заведение привычки: карточка типа и редактор»


Что здесь решается: человек нажимает «плюс» в списке, видит **четыре** карточки
вместо трёх, выбирает «Воздержание», и форма, которую он получает, — это форма
воздержания, а не форма числовой привычки. Сохранение пишет привычку и строку
`HabitDefinitions` с `kind = 'abstinence'`, днём обязательства и допуском в
payload. Всё, кроме имени, имеет значение по умолчанию: форму можно сохранить,
не тронув ни одного поля.

### Что форма воздержания показывает и чего не показывает

Показывает: имя и цвет, вопрос (со своей подсказкой), **допуск с единицей**
(одна строка, два поля), **день обязательства**, напоминание, заметки.

Не показывает: частоту (у воздержания она прибита к `Frequency(1, 1)` —
спецификация, «Отдельно: значение дня»), числовые «Единица», «Цель» и «Тип
цели» — их settle-ит сохранение, — и числовой выбор частоты, который в
оригинале делит строку с «Целью». Напоминание показывается, но по умолчанию
выключено (`reminderHour = -1` — это и так значение по умолчанию модели):
открытый вопрос 2 спецификации решён именно так, и ни строчки кода на это не
нужно.

### Отступление от паритета: что четвёртая карточка делает с правилом

`habit-type-dialog.select-type#4` гласит: **ровно две** карточки, «Да/Нет» и
«Измеримая». Порт уже показывает три, и это записано в
`docs/parity/DEVIATIONS.md` под заголовком
`### sleep: третья карточка в выборе типа привычки` (строки 750–765) —
формулировка там штучная: «Порт показывает третью — „Сон“… третья идёт
последней».

Четвёртая карточка **не создаёт нового отступления** — она превращает
единичное исключение в форму: у порта есть класс карточек, которых нет в
оригинале, по одной на вычисляемый вид. Поэтому:

- `docs/parity/FEATURES.md` не меняется ни строкой (он неизменяем), правило
  `#4` остаётся как есть;
- запись в `DEVIATIONS.md` переписывается из «третья карточка» в «карточки
  вычисляемых видов» — иначе она станет ложной ровно в тот момент, когда
  карточек станет четыре;
- паритетный тест, который сегодня меряет вертикальное центрирование колонки
  по `first.top .. third.bottom`
  (`app/test/ui/habits/edit/edit_habit_screen_test.dart:3034-3047` — от
  комментария «The port adds a third card of its own…» до закрывающей
  `moreOrLessEquals(screen.height / 2, epsilon: 0.5)`), обязан
  мерить по `first.top .. fourth.bottom` — иначе он падает, и падает
  правильно: колонка действительно стала выше;
- цитата `sleep.ui#6` в том же тесте («карточка порта идёт последней») больше
  не про сон: утверждение теперь про два вида. Она заменяется на
  `computed.create#1`. `sleep.ui#6` остаётся процитированным в 20 других
  местах (`test/ui/sleep/*`), так что `parity_coverage` от этого не краснеет.

### Task 25: `ComputedKind` вместо флага `sleep` на пути создания (5-create.1)

Сегодня вид, выбранный в карточках, едет до модели как `bool sleep`. Второй
вычисляемый вид этот флаг не переживает: `bool` умеет сказать «сон» и «не
сон», а сказать «воздержание» не умеет. Заменяем флаг на `ComputedKind?` —
`null` значит обычная привычка.

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/edit_habit_model.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/edit/edit_habit_screen.dart`
- Modify (механически, `sleep: true` → `computed: ComputedKind.sleep`):
  `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/sleep/sleep_editor_test.dart`,
  `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/sleep/sleep_editor_screen_test.dart`,
  `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_sleep_pairing_test.dart`,
  `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/sleep_sync_wiring_test.dart`
- Test (создать): `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_test.dart`

**Interfaces:**
- Consumes: `ComputedKind` (`packages/uhabits_core/lib/src/computed/habit_definition.dart`, экспортируется из `uhabits_core.dart`), `AppScope.definitions` (`DefinitionRepository`).
- Produces:
  - `EditHabitModel({required AppScope scope, int? habitId, HabitType habitType = HabitType.yesNo, ComputedKind? computed})`
  - `ComputedKind? EditHabitModel.computedKind`
  - `bool get EditHabitModel.isAbstinence`
  - `bool get EditHabitModel.isComputed`
  - `EditHabitScreen({Key? key, int? habitId, core.HabitType habitType, core.ComputedKind? computed})`
  - `static Route<void> EditHabitScreen.route({required AppScope scope, int? habitId, core.HabitType habitType = core.HabitType.yesNo, core.ComputedKind? computed})`
  - `HabitTypeSelection(core.HabitType type, {core.ComputedKind? computed})`, поле `final core.ComputedKind? computed`

**Шаги:**

1. Завести падающий тест. Создать
   `app/test/ui/abstinence/abstinence_editor_test.dart`:

```dart
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
```

2. `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/ui/abstinence/abstinence_editor_test.dart`.
   Падает на компиляции:
   `Error: No named parameter with the name 'computed'.` и
   `Error: The getter 'computedKind' isn't defined for the class 'EditHabitModel'.`

3. В `app/lib/state/edit_habit_model.dart` заменить сигнатуру и тело головы
   конструктора. Было:

```dart
  EditHabitModel({
    required this.scope,
    int? habitId,
    HabitType habitType = HabitType.yesNo,
    bool sleep = false,
  }) {
    final id = habitId;
    if (id == null) {
      this.habitType = sleep ? sleepHabitType : habitType;
      if (sleep) {
```

   Стало:

```dart
  EditHabitModel({
    required this.scope,
    int? habitId,
    HabitType habitType = HabitType.yesNo,
    ComputedKind? computed,
  }) {
    final id = habitId;
    if (id == null) {
      computedKind = computed;
      // Every computed kind is a numerical habit — `sleepHabitType` is that
      // same constant, spelled for sleep. There is no third `HabitType` and
      // there will not be one: `models.habit-type-enums#1` closes the enum at
      // two, and both tests on it pass unchanged.
      this.habitType = computed == null ? habitType : HabitType.numerical;
      if (computed == ComputedKind.sleep) {
```

   и закрыть сонную ветку как была (`sleepGoal = SleepGoal(...); }`).

4. Добавить поля и производные рядом с `sleepGoal` (после
   `bool get isSleep => sleepGoal != null;`):

```dart
  /// What computes this habit's days, or null for an ordinary habit.
  ///
  /// In CREATE it is what the type chooser came back with. In EDIT it is read
  /// from the definition row, because the form has no control that could
  /// change it: a habit's kind is settled when it is created and there is no
  /// code, in either direction, that would move it (DEVIATIONS.md, "computed:
  /// вид привычки после создания не меняется").
  ComputedKind? computedKind;

  bool get isAbstinence => computedKind == ComputedKind.abstinence;

  /// Whether the app computes this habit's days, by either route.
  ///
  /// [isSleep] is deliberately still the goal rather than the kind: in CREATE
  /// the goal exists before any definition row does, and a sleep habit whose
  /// definition row went missing must keep showing its own fields.
  bool get isComputed => isSleep || computedKind != null;
```

5. В том же файле, в EDIT-ветке конструктора, сразу после
   `sleepGoal = scope.sleepRepository.goalFor(id);` добавить:

```dart
    computedKind = scope.definitions.forHabit(id)?.kind;
```

6. В `app/lib/ui/habits/edit/edit_habit_screen.dart` заменить поле экрана. Было:

```dart
    this.sleep = false,
  });

  final int? habitId;

  final core.HabitType habitType;

  /// Start the form as a sleep goal.
  ///
  /// Only ever true for a new habit: an existing one is a sleep habit exactly
  /// when a goal is already stored for it.
  final bool sleep;
```

   Стало:

```dart
    this.computed,
  });

  final int? habitId;

  final core.HabitType habitType;

  /// Start the form as a computed habit of this kind.
  ///
  /// Only ever set for a new habit: an existing one carries its kind in its
  /// definition row, and the form reads it from there.
  final core.ComputedKind? computed;
```

7. В том же файле поправить три места, где `sleep` пробрасывался:

```dart
    core.HabitType habitType = core.HabitType.yesNo,
    core.ComputedKind? computed,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'editHabit'),
      builder: (context) => Provider<AppScope>.value(
        value: scope,
        child: EditHabitScreen(
          habitId: habitId,
          habitType: habitType,
          computed: computed,
        ),
      ),
    );
```

```dart
    await navigator.push(route(
      scope: scope,
      habitType: selection.type,
      computed: selection.computed,
    ));
```

```dart
      create: (context) => EditHabitModel(
        scope: context.read<AppScope>(),
        habitId: habitId,
        habitType: habitType,
        computed: computed,
      ),
```

8. Заменить `HabitTypeSelection`:

```dart
/// What the type chooser came back with.
///
/// A pair rather than a bare [core.HabitType] because a computed habit is
/// stored as a numerical one: the type alone cannot tell three kinds apart.
class HabitTypeSelection {
  const HabitTypeSelection(this.type, {this.computed});

  final core.HabitType type;
  final core.ComputedKind? computed;

  @override
  bool operator ==(Object other) =>
      other is HabitTypeSelection &&
      other.type == type &&
      other.computed == computed;

  @override
  int get hashCode => Object.hash(type, computed);
}
```

   и карточку сна:

```dart
                  onTap: () => Navigator.of(context).pop(
                      const HabitTypeSelection(core.HabitType.numerical,
                          computed: core.ComputedKind.sleep)),
```

9. Механически заменить в четырёх тестовых файлах `sleep: true` на
   `computed: ComputedKind.sleep` там и только там, где аргумент идёт в
   `EditHabitModel(...)` или в `EditHabitScreen.route(...)`:
   `test/ui/sleep/sleep_editor_test.dart` (11 мест),
   `test/state/computed_sleep_pairing_test.dart` (3 места),
   `test/state/sleep_sync_wiring_test.dart` (1 место),
   `test/ui/sleep/sleep_editor_screen_test.dart` (в локальном `pumpEditor`
   заменить и параметр: `Future<void> pumpEditor(WidgetTester tester,
   {required bool sleep})` → тело `EditHabitScreen.route(scope: scope,
   habitType: sleep ? sleepHabitType : HabitType.numerical, computed: sleep ?
   ComputedKind.sleep : null)`).
   Не трогать `test/ui/sleep/sleep_habit_screen_test.dart` и
   `test/state/sleep_entry_routing_test.dart`: там `sleep: true` — аргумент их
   собственного локального `addHabit`, к `EditHabitModel` отношения не имеющий.

10. `flutter test test/ui/abstinence/ test/ui/sleep/ test/state/computed_sleep_pairing_test.dart test/state/sleep_sync_wiring_test.dart test/ui/habits/edit/` — зелено.

11. Коммит: `create: carry a ComputedKind through the editor instead of a sleep flag`.

**Мутация (чем тест дискриминирует):** в шаге 3 написать
`this.habitType = computed == null ? habitType : HabitType.numerical;` →
`this.habitType = habitType;`. Тест из шага 1 останется зелёным, но
`test/ui/sleep/sleep_editor_test.dart` «saving settles the numerical
parameters the model needs» упадёт на `expect(habit.type, sleepHabitType)`.
Убрать `computedKind = computed;` — упадёт первый `expect` нового теста
(`ComputedKind.abstinence` vs `null`). Заменить `isComputed` на
`=> isSleep` — упадёт `expect(abstinence.isComputed, isTrue)`.
Возврат мутации — обратной текстовой заменой, не `git checkout`.

---

### Task 26: строки, реестр правил и инвентарь локализации (5-create.2)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/l10n/app_en.arb`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/l10n/app_ru.arb`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/l10n/localization_inventory_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`

**Interfaces:**
- Produces: восемь геттеров на `L10n` — `abstinenceHabitType`,
  `abstinenceHabitTypeExample`, `abstinenceQuestionExample`,
  `abstinenceAllowance`, `abstinenceAllowanceExample`,
  `abstinenceAllowanceUnit`, `abstinenceAllowanceUnitExample`,
  `abstinenceCommittedFrom` (все `String`, без подстановок).
- Produces: `const Set<String> extensionPrefixes` в
  `test/l10n/localization_inventory_test.dart`.
- Produces: блок правил `computed.create` (#1–#11) в `docs/extensions/COMPUTED.md`.

**Шаги:**

1. Дописать в `app/lib/l10n/app_en.arb` перед закрывающей `}` (после
   `sleepTimezoneOffset`, добавив запятую к предыдущему блоку):

```json
  "abstinenceHabitType": "Abstinence",
  "@abstinenceHabitType": {
    "description": "Title of the habit-type card for \"I commit not to do X\"."
  },
  "abstinenceHabitTypeExample": "e.g. No alcohol. No doomscrolling. Silence is a clean day — you only mark the days you slipped.",
  "abstinenceQuestionExample": "e.g. Did you slip today?",
  "@abstinenceQuestionExample": {
    "description": "Placeholder for the question an abstinence habit asks."
  },
  "abstinenceAllowance": "Allowance",
  "@abstinenceAllowance": {
    "description": "Label of the field holding how much a day may hold before it counts as a slip."
  },
  "abstinenceAllowanceExample": "e.g. 30",
  "abstinenceAllowanceUnit": "Counted in",
  "abstinenceAllowanceUnitExample": "e.g. minutes",
  "abstinenceCommittedFrom": "Committed since"
```

2. Дописать в `app/lib/l10n/app_ru.arb` перед закрывающей `}` (после
   `sleepTimezoneOffset`, добавив запятую):

```json
  "abstinenceHabitType": "Воздержание",
  "abstinenceHabitTypeExample": "напр.: Не пить. Не листать ленту. Молчание — чистый день; отмечать нужно только срывы.",
  "abstinenceQuestionExample": "напр.: Были срывы сегодня?",
  "abstinenceAllowance": "Допуск",
  "abstinenceAllowanceExample": "напр.: 30",
  "abstinenceAllowanceUnit": "Считается в",
  "abstinenceAllowanceUnitExample": "напр.: минуты",
  "abstinenceCommittedFrom": "Обязательство с"
```

3. `flutter test test/l10n/localization_inventory_test.dart`. Падает —
   и это ровно то падение, ради которого шаг сделан именно в этом порядке:
   `platform-glue.localization-inventory#4: which leaves 178 ported strings`
   получает 186, потому что восемь строк расширения посчитались
   перенесёнными. Второе падение — `#2` (число обычных сообщений в шаблоне).

4. Расширить фильтр расширений в
   `app/test/l10n/localization_inventory_test.dart`. Было:

```dart
const String extensionPrefix = 'sleep';

/// Whether [key] is a message the original defines.
bool isPorted(String key) => !key.startsWith(extensionPrefix);
```

   Стало:

```dart
/// The prefixes a message of an extension carries — one per extension.
///
/// A set rather than a string: `sleep` was the only extension for exactly as
/// long as there was one computed kind, and a filter that names one of them is
/// a filter that quietly re-counts the second as ported.
const Set<String> extensionPrefixes = <String>{'sleep', 'abstinence'};

/// Whether [key] is a message the original defines.
bool isPorted(String key) =>
    !extensionPrefixes.any((String prefix) => key.startsWith(prefix));
```

5. Дописать в тот же файл, в группу
   `group('platform-glue.localization-inventory', ...)`, отдельную проверку —
   иначе расширение фильтра нечем отличить от его отключения:

```dart
    test('every extension message is behind a declared prefix', () {
      final Set<String> extension =
          messagesOf(template).difference(portedMessagesOf(template));
      expect(extension, isNotEmpty,
          reason: 'platform-glue.localization-inventory#4 (deviation) — the '
              'port has extensions, and their strings are counted apart');
      for (final String key in extension) {
        expect(extensionPrefixes.any(key.startsWith), isTrue,
            reason: 'platform-glue.localization-inventory#4 (deviation) — '
                '$key is excluded from the ported count, so it has to be '
                'named by a prefix rather than by accident');
      }
      expect(extension.where((String k) => k.startsWith('abstinence')).length,
          8,
          reason: 'platform-glue.localization-inventory#4 (deviation) — the '
              'abstinence editor adds exactly eight strings, and a ninth that '
              'nobody declared would be one nobody translated');
    });
```

   **Число буквальное — в этом его смысл**, и именно поэтому оно ещё изменится:
   Задача 32 добавляет шесть строк ячейки и экрана привычки, и это **единственная
   строка**, которую та задача обязана здесь поправить — на 14, с перечислением
   обеих групп. Держать здесь сразу 14 нельзя: шести строк ещё нет, и тест упал
   бы в задаче, которая их не добавляла.

   Расширение фильтра (`extensionPrefixes`) остаётся здесь, а не уезжает
   вперёд: восемь строк расширения появляются в **этой** задаче, и без фильтра
   падают три портированных ожидания инвентаря.

6. `flutter test test/l10n/` — зелено. `flutter gen-l10n` (или ближайший
   `flutter test`, который его дёргает) должен породить восемь геттеров;
   проверить `grep -c abstinence app/.dart_tool/flutter_gen/gen_l10n/app_localizations.dart`
   — не ноль.

7. Дописать в `docs/extensions/COMPUTED.md` в конец файла блок правил,
   **невзведённым** (`- [ ]`): `parity_coverage --verify` ругается только на
   взведённые фичи с нецитированными правилами, поэтому взводим его в
   Task 5-create.7, когда все тесты написаны.

```markdown
- [ ] `computed.create`
1. `computed.create#1` Карточки оригинала идут первыми и в своём порядке; карточки вычисляемых видов — после них, по одной на вид.
2. `computed.create#2` Выбор вида едет до формы видом, а не флагом: обычная привычка, сон и воздержание различимы.
3. `computed.create#3` Форма воздержания не показывает ни частоту, ни числовые «Единица», «Цель» и «Тип цели».
4. `computed.create#4` Форма воздержания показывает допуск с единицей и день обязательства.
5. `computed.create#5` Новая привычка-воздержание сохраняется, когда заполнено только имя.
6. `computed.create#6` Привычка-воздержание сохраняется как числовая: тип цели «не больше», частота 1/1, целевое значение равно допуску, единица — введённая.
7. `computed.create#7` Сохранение пишет строку определения вида abstinence с днём обязательства и payload, несущим допуск и единицу.
8. `computed.create#8` День обязательства по умолчанию — сегодня и не может оказаться в будущем.
9. `computed.create#9` Определение пишется и тогда, когда команда выполняется не сразу, — на устройстве, а не только в синхронной обвязке.
10. `computed.create#10` Вид существующей привычки читается из строки определения; обычная привычка ни на одном пути редактора вычисляемой не становится.
11. `computed.create#11` Пустой допуск сохраняется нулём, нечисловой — отказывает в сохранении.
```

8. Коммит: `create: strings and rules for the abstinence editor`.

**Мутация:** вернуть `isPorted` к `!key.startsWith('sleep')` — упадёт
`platform-glue.localization-inventory#4` (186 вместо 178). Убрать
`'abstinence'` из `extensionPrefixes`, оставив функцию — упадёт то же самое.
Заменить в новом тесте `8` на `greaterThan(0)` — тест перестанет ловить
девятую недекларированную строку, что и есть его смысл; поэтому число
буквальное.

---

### Task 27: четвёртая карточка в выборе типа (5-create.3)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/edit/edit_habit_screen.dart`
- Test (создать): `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_screen_test.dart`
- Test (изменить): `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/edit/edit_habit_screen_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`

**Interfaces:**
- Produces: `static const Key EditHabitScreen.abstinenceTypeCardKey = Key('habitType.abstinenceCard')`
- Produces: карточка отдаёт `HabitTypeSelection(core.HabitType.numerical, computed: core.ComputedKind.abstinence)`

**Шаги:**

1. Создать `app/test/ui/abstinence/abstinence_editor_screen_test.dart` с
   обвязкой по образцу `test/ui/sleep/sleep_editor_screen_test.dart`
   (`Sqlite3Database.memory()`, `setVersion(8)`, `migrateTo(appDatabaseVersion,
   ...)`, `AppScope.open` на `UnconfinedTestDispatcher`) плюс:

```dart
  Future<void> pumpChooser(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => EditHabitScreen.selectTypeAndOpen(context),
                  child: const Text('host'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }
```

   и первый тест:

```dart
  testWidgets('the chooser offers abstinence, last', (tester) async {
    await pumpChooser(tester);

    expect(find.byKey(EditHabitScreen.abstinenceTypeCardKey), findsOneWidget,
        reason: 'computed.create#1');
    expect(find.text('Abstinence'), findsOneWidget,
        reason: 'computed.create#1');

    final Rect yesNo =
        tester.getRect(find.byKey(EditHabitScreen.yesNoTypeCardKey));
    final Rect measurable =
        tester.getRect(find.byKey(EditHabitScreen.measurableTypeCardKey));
    final Rect sleep =
        tester.getRect(find.byKey(EditHabitScreen.sleepTypeCardKey));
    final Rect abstinence =
        tester.getRect(find.byKey(EditHabitScreen.abstinenceTypeCardKey));

    // The two ported cards keep the positions `habit-type-dialog.select-type#4`
    // gives them; the port's own cards go under them, one per kind.
    expect(measurable.top, greaterThan(yesNo.top),
        reason: 'computed.create#1');
    expect(sleep.top, greaterThan(measurable.top),
        reason: 'computed.create#1');
    expect(abstinence.top, greaterThan(sleep.top),
        reason: 'computed.create#1 — a new kind lands below the kinds that '
            'were already there, so nobody\'s muscle memory moves');
  });

  testWidgets('picking it opens the editor as an abstinence habit',
      (tester) async {
    await pumpChooser(tester);
    await tester.tap(find.byKey(EditHabitScreen.abstinenceTypeCardKey));
    await tester.pumpAndSettle();

    final EditHabitModel model = Provider.of<EditHabitModel>(
      tester.element(find.byKey(EditHabitScreen.saveButtonKey)),
      listen: false,
    );
    expect(model.computedKind, ComputedKind.abstinence,
        reason: 'computed.create#2 — the card that was tapped is the kind the '
            'form is holding');
    expect(model.habitType, HabitType.numerical,
        reason: 'computed.create#2 — and it is a numerical habit, because '
            'there is no third type and never will be');
  });
```

2. `flutter test test/ui/abstinence/abstinence_editor_screen_test.dart`.
   Падает на компиляции:
   `Error: Member not found: 'EditHabitScreen.abstinenceTypeCardKey'.`

3. В `app/lib/ui/habits/edit/edit_habit_screen.dart` рядом с
   `static const Key sleepTypeCardKey = Key('habitType.sleepCard');` добавить:

```dart
  static const Key abstinenceTypeCardKey = Key('habitType.abstinenceCard');
```

4. В `HabitTypeDialog.build`, после карточки сна и её `);`, добавить:

```dart
                const SizedBox(height: 16),
                // The port's fourth card. `habit-type-dialog.select-type#4`
                // says exactly two, and the port has departed from it once
                // already, for sleep; this does not depart from it a second
                // time, it makes the first departure a shape: one card per
                // computed kind, all of them after the two the original has.
                // DEVIATIONS.md carries the entry, widened from "the third
                // card" to this.
                _HabitTypeCard(
                  key: EditHabitScreen.abstinenceTypeCardKey,
                  title: l10n.abstinenceHabitType,
                  body: l10n.abstinenceHabitTypeExample,
                  onTap: () => Navigator.of(context).pop(
                      const HabitTypeSelection(core.HabitType.numerical,
                          computed: core.ComputedKind.abstinence)),
                ),
```

5. `flutter test test/ui/abstinence/abstinence_editor_screen_test.dart` — зелено.

6. `flutter test test/ui/habits/edit/edit_habit_screen_test.dart` — падает:
   `habit-type-dialog.select-type#3 — vertically centred` (колонка выросла на
   карточку, середина уехала примерно на её половину). Это правильное падение.
   Починить, заменив в
   `app/test/ui/habits/edit/edit_habit_screen_test.dart` блок:

```dart
      // The port adds a third card of its own, below those two, for a goal the
      // original cannot express. That is a deliberate departure from
      // `habit-type-dialog.select-type#4`, which says exactly two, and it is
      // recorded in DEVIATIONS.md. The centring below therefore measures the
      // column the port actually shows.
      final third = tester.getRect(find.byKey(EditHabitScreen.sleepTypeCardKey));
      expect(third.top, greaterThan(second.top),
          reason: 'sleep.ui#6 — the port\'s own card comes last, so the two '
              'ported cards keep the positions the rule gives them');
      expect(
        (first.top + third.bottom) / 2,
        moreOrLessEquals(screen.height / 2, epsilon: 0.5),
        reason: 'habit-type-dialog.select-type#3 — vertically centred',
      );
```

   на:

```dart
      // The port adds a card of its own per computed kind, below those two,
      // for goals the original cannot express. That is a deliberate departure
      // from `habit-type-dialog.select-type#4`, which says exactly two, and it
      // is recorded in DEVIATIONS.md. The centring below therefore measures
      // the column the port actually shows.
      final third = tester.getRect(find.byKey(EditHabitScreen.sleepTypeCardKey));
      final fourth =
          tester.getRect(find.byKey(EditHabitScreen.abstinenceTypeCardKey));
      expect(third.top, greaterThan(second.top),
          reason: 'computed.create#1 — the port\'s own cards come last, so the '
              'two ported cards keep the positions the rule gives them');
      expect(fourth.top, greaterThan(third.top),
          reason: 'computed.create#1 — and they are in a column too');
      expect(
        (first.top + fourth.bottom) / 2,
        moreOrLessEquals(screen.height / 2, epsilon: 0.5),
        reason: 'habit-type-dialog.select-type#3 — vertically centred',
      );
```

   (в файле строка с `sleep.ui#6` записана буквально, без экранирования — при
   замене брать её как есть.)

7. `flutter test test/ui/habits/edit/edit_habit_screen_test.dart` — зелено.

8. Переписать запись в `docs/parity/DEVIATIONS.md`. Заменить заголовок и текст
   (строки 750–765) — было:

```markdown
### sleep: третья карточка в выборе типа привычки

Правило `habit-type-dialog.select-type#4` гласит: ровно две карточки, «Да/Нет»
и «Измеримая». Порт показывает третью — «Сон».
```

   стало:

```markdown
### computed: карточки вычисляемых видов в выборе типа привычки

Правило `habit-type-dialog.select-type#4` гласит: ровно две карточки, «Да/Нет»
и «Измеримая». Порт показывает по карточке на каждый вычисляемый вид сверх
них: «Сон» и «Воздержание».
```

   и заменить абзац

```markdown
Две перенесённые карточки сохраняют свои заголовки, тексты, порядок и
поведение; третья идёт последней. Паритетный тест это и проверяет.

Влияние на пользователя: при создании привычки предлагается на один вариант
больше.
```

   на

```markdown
Две перенесённые карточки сохраняют свои заголовки, тексты, порядок и
поведение; карточки порта идут после них, каждая своя на вид, в порядке
появления видов. Паритетный тест это и проверяет: он меряет вертикальное
центрирование по всей колонке, которую порт показывает на самом деле, а не по
двум перенесённым карточкам.

Влияние на пользователя: при создании привычки предлагается на два варианта
больше.
```

9. Коммит: `create: a fourth habit-type card for abstinence`.

**Мутация:** переставить четвёртую карточку выше сонной — упадёт
`expect(abstinence.top, greaterThan(sleep.top))`. Отдать из `onTap`
`HabitTypeSelection(core.HabitType.numerical)` без `computed:` — упадёт
`expect(model.computedKind, ComputedKind.abstinence)`. Оставить в паритетном
тесте центрирование по `third.bottom` — упадёт
`habit-type-dialog.select-type#3 — vertically centred`.

---

### Task 28: поля воздержания в форме и форма привычки при сохранении (5-create.4)

Допуск и его единица — это те же два контроллера, которые числовая форма зовёт
«Цель» и «Единица», заданные другим вопросом. Переиспользуем их (`targetController`,
`unitController`), а не заводим третий и четвёртый: у воздержания
`habit.targetValue` **и есть** допуск, а `habit.unit` **и есть** его единица.

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/edit_habit_model.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/edit/edit_habit_screen.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_test.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_screen_test.dart`

**Interfaces:**
- Produces: `int EditHabitModel.committedFrom` (`daysSince2000`)
- Produces: `void EditHabitModel.setCommittedFrom(int day)` (клампит будущее к сегодня)
- Produces: `EditHabitFieldError? EditHabitModel.allowanceError`
- Produces: `static const Key EditHabitScreen.abstinenceAllowanceBoxKey = Key('editHabit.abstinenceAllowanceOuterBox')`
- Produces: `static const Key EditHabitScreen.abstinenceAllowanceFieldKey = Key('editHabit.abstinenceAllowanceInput')`
- Produces: `static const Key EditHabitScreen.abstinenceUnitFieldKey = Key('editHabit.abstinenceUnitInput')`
- Produces: `static const Key EditHabitScreen.abstinenceCommittedBoxKey = Key('editHabit.abstinenceCommittedOuterBox')`
- Produces: `static const Key EditHabitScreen.abstinenceCommittedPickerKey = Key('editHabit.abstinenceCommittedPicker')`

**Шаги:**

1. Дописать в `app/test/ui/abstinence/abstinence_editor_test.dart`:

```dart
  group('defaults', () {
    test('a new abstinence habit can be saved with nothing but a name', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';

      expect(model.save(), isTrue,
          reason: 'computed.create#5 — every field of this form has a default, '
              'so a person who commits and types a name is done');
      expect(model.targetError, isNull, reason: 'computed.create#5');
      expect(model.allowanceError, isNull, reason: 'computed.create#5');
      expect(scope.habitList.size(), 1, reason: 'computed.create#5');
    });

    test('the allowance starts at zero: one tap is a slip', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      expect(model.targetController.text, '0',
          reason: 'computed.create#5 — the default is "any slip counts", and '
              'it is on screen rather than implied');
    });

    test('the commitment day starts today and cannot be moved forward', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      expect(model.committedFrom, 9000, reason: 'computed.create#8');

      model.setCommittedFrom(8960);
      expect(model.committedFrom, 8960,
          reason: 'computed.create#8 — backwards is the whole point: forty '
              'clean days before the first slip have to exist');

      model.setCommittedFrom(9001);
      expect(model.committedFrom, 9000,
          reason: 'computed.create#8 — a habit committed to tomorrow would '
              'score days nobody has lived');
    });
  });

  group('the habit an abstinence habit is stored as', () {
    test('at-most, daily, target equal to the allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.unitController.text = 'minutes';
      expect(model.save(), isTrue, reason: 'computed.create#6');

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.type, HabitType.numerical, reason: 'computed.create#6');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'computed.create#6 — "no more than the allowance" is what '
              'at-most already means, and its score starts at 1.0');
      expect(habit.targetValue, 30.0,
          reason: 'computed.create#6 — a slip starts past the allowance, so '
              'the allowance is the target');
      expect(habit.unit, 'minutes', reason: 'computed.create#6');
      expect(habit.frequency.numerator, 1, reason: 'computed.create#6');
      expect(habit.frequency.denominator, 1,
          reason: 'computed.create#6 — the frequency is pinned: it sets the '
              'decay through sqrt(frequency), the width of the rolling window '
              'and the list cell threshold all at once');
    });

    test('a blank allowance is zero; a word where a number belongs refuses',
        () {
      final EditHabitModel blank =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      blank.nameController.text = 'No alcohol';
      blank.targetController.text = '';
      expect(blank.save(), isTrue, reason: 'computed.create#11');
      expect(scope.habitList.getByPosition(0).targetValue, 0.0,
          reason: 'computed.create#11 — an emptied allowance means none');

      final EditHabitModel wrong =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      wrong.nameController.text = 'No doomscrolling';
      wrong.targetController.text = 'lots';
      expect(wrong.save(), isFalse, reason: 'computed.create#11');
      expect(wrong.allowanceError, EditHabitFieldError.notANumber,
          reason: 'computed.create#11 — the error lands on the allowance, not '
              'on the target field the form never showed');
      expect(scope.habitList.size(), 1,
          reason: 'computed.create#11 — and nothing was created');
    });
  });
```

2. `flutter test test/ui/abstinence/abstinence_editor_test.dart` — падает:
   `Error: The getter 'committedFrom' isn't defined for the class 'EditHabitModel'.`

3. В `app/lib/state/edit_habit_model.dart` добавить поле и ошибку рядом с
   `EditHabitFieldError? targetError;`:

```dart
  /// The allowance field's error. Its own rather than [targetError]: the form
  /// that shows the allowance never shows the target, so an error on the one
  /// would be drawn on a box that is not on screen.
  EditHabitFieldError? allowanceError;

  /// The day the person committed, as `daysSince2000`.
  ///
  /// Only an abstinence habit has one, and it is what the recompute range
  /// starts from. It cannot come from the entries: a habit that records
  /// nothing while it is being kept has no oldest entry, and the first row it
  /// ever gets is the first slip — which would make the clean stretch before
  /// it not exist.
  int committedFrom = 0;
```

4. В CREATE-ветке конструктора, после сонного `if`, добавить:

```dart
      if (computed == ComputedKind.abstinence) {
        // Everything this form asks for has a default, so it can be saved with
        // nothing but a name: today, and no allowance at all.
        committedFrom = getToday().daysSince2000;
        targetController.text = '0';
      }
```

5. В EDIT-ветке, сразу после `computedKind = scope.definitions.forHabit(id)?.kind;`
   (Task 5-create.1, шаг 5), заменить эту строку на:

```dart
    final HabitDefinition? definition = scope.definitions.forHabit(id);
    computedKind = definition?.kind;
    committedFrom = definition?.committedFrom ?? getToday().daysSince2000;
    if (computedKind == ComputedKind.abstinence) {
      // `targetValue.toString()` renders 30 as "30.0", which is what the
      // ported line above does and what its rule asks for. An allowance is a
      // count of minutes or of drinks, and "30.0 minutes" is not how anyone
      // writes one down.
      final double allowance = habit.targetValue;
      targetController.text = allowance == allowance.roundToDouble()
          ? allowance.round().toString()
          : allowance.toString();
    }
```

6. Добавить сеттер рядом с `setSleepGoal`:

```dart
  /// The commitment day, never in the future.
  ///
  /// The picker's `lastDate` already refuses tomorrow; this refuses it again,
  /// because the picker is one of three ways this value can be set and the
  /// other two are a restored backup and a future build.
  void setCommittedFrom(int day) {
    final int today = getToday().daysSince2000;
    committedFrom = day > today ? today : day;
    notifyListeners();
  }
```

7. В `validate()` заменить

```dart
    var isValid = true;
    nameError = null;
    targetError = null;
```

   на

```dart
    var isValid = true;
    nameError = null;
    targetError = null;
    allowanceError = null;
```

   заменить `if (isNumerical && !isSleep) {` на `if (isNumerical && !isComputed) {`
   и дописать перед `notifyListeners();`:

```dart
    // The allowance is the same control asked a different question. Blank is
    // not an error here — it means no allowance, which is the default — but a
    // word where a number belongs still refuses the save, for the reason
    // `edit-habit.validation#9` gives about the target.
    if (isAbstinence &&
        targetController.text.isNotEmpty &&
        double.tryParse(targetController.text) == null) {
      allowanceError = EditHabitFieldError.notANumber;
      isValid = false;
    }
```

8. В `save()` заменить `if (habitType == HabitType.numerical && !isSleep) {`
   на `if (habitType == HabitType.numerical && !isComputed) {` и дописать
   после сонного блока `if (isSleep) { ... }`:

```dart
    // An abstinence habit is an at-most numerical habit whose target is the
    // day's allowance. Nothing new is needed for "silence is success": the
    // ported at-most branch starts its score at 1.0 and counts a day with no
    // entry through `max(0, -1)`, which is exactly "innocent until proven
    // otherwise".
    if (isAbstinence) {
      habit.targetValue = double.tryParse(targetController.text) ?? 0;
      habit.targetType = NumericalHabitType.atMost;
      habit.unit = unitController.text.trim();
      habit.frequency = Frequency(1, 1);
    }
```

9. `flutter test test/ui/abstinence/abstinence_editor_test.dart` — зелено.

10. Дописать в `app/test/ui/abstinence/abstinence_editor_screen_test.dart`
    (нужен `pumpEditor`, открывающий редактор напрямую с
    `EditHabitScreen.route(scope: scope, habitType: HabitType.numerical,
    computed: ComputedKind.abstinence)` — по образцу `pumpChooser` из
    Task 5-create.3):

```dart
  testWidgets('the form asks about the allowance, not about miles run',
      (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);

    expect(find.byKey(EditHabitScreen.abstinenceAllowanceBoxKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.byKey(EditHabitScreen.abstinenceCommittedBoxKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.text('Allowance'), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.text('Committed since'), findsOneWidget,
        reason: 'computed.create#4');

    // What it must NOT show: the four numerical boxes and the yes/no
    // frequency. Every one of them would let a person change something the
    // kind settles — the frequency it is scored at, the unit and the target
    // that ARE the allowance, and the target type that is what makes silence
    // count as success.
    expect(find.byKey(EditHabitScreen.unitBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.targetBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.frequencyBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.numericalFrequencyPickerKey), findsNothing,
        reason: 'computed.create#3 — the numerical frequency shares a row with '
            'the target upstream, and that row is not on this form');

    // And what it keeps: the reminder, off, which is the answer to the spec\'s
    // second open question.
    expect(find.byKey(EditHabitScreen.reminderTimePickerKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.byKey(EditHabitScreen.reminderDividerKey), findsNothing,
        reason: 'computed.create#4 — there is nothing to confirm every '
            'evening, so the reminder starts off');
  });

  testWidgets('the question box has its own example', (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final TextField question = tester.widget<TextField>(find.descendant(
      of: find.byKey(EditHabitScreen.questionFieldKey),
      matching: find.byType(TextField),
    ));
    expect(question.decoration!.hintText, 'e.g. Did you slip today?',
        reason: 'computed.create#4 — the placeholder is the only thing on the '
            'form that says what the question is for');
  });

  testWidgets('the commitment day reads as a date and starts today',
      (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final Text shown = tester.widget<Text>(find.descendant(
      of: find.byKey(EditHabitScreen.abstinenceCommittedPickerKey),
      matching: find.byType(Text),
    ).first);
    expect(shown.data, IntlLocalDateFormatter('en').longFormat(LocalDate(9000)),
        reason: 'computed.create#8 — a day number is not a date a person can '
            'check');
  });
```

11. `flutter test test/ui/abstinence/abstinence_editor_screen_test.dart` —
    падает: `Member not found: 'EditHabitScreen.abstinenceAllowanceBoxKey'.`

12. В `app/lib/ui/habits/edit/edit_habit_screen.dart` добавить ключи рядом с
    `abstinenceTypeCardKey`:

```dart
  static const Key abstinenceAllowanceBoxKey =
      Key('editHabit.abstinenceAllowanceOuterBox');
  static const Key abstinenceAllowanceFieldKey =
      Key('editHabit.abstinenceAllowanceInput');
  static const Key abstinenceUnitFieldKey =
      Key('editHabit.abstinenceUnitInput');
  static const Key abstinenceCommittedBoxKey =
      Key('editHabit.abstinenceCommittedOuterBox');
  static const Key abstinenceCommittedPickerKey =
      Key('editHabit.abstinenceCommittedPicker');
```

13. В `_buildForm` заменить

```dart
      if (model.isSleep)
        SleepGoalFields(
          theme: theme,
          goal: model.sleepGoal!,
          onChanged: model.setSleepGoal,
        )
      else if (model.isNumerical) ...<Widget>[
```

    на

```dart
      if (model.isSleep)
        SleepGoalFields(
          theme: theme,
          goal: model.sleepGoal!,
          onChanged: model.setSleepGoal,
        )
      // An abstinence habit is stored as a numerical one too, and the same
      // reasoning applies: its unit, target, target type and frequency are
      // settled by the kind. Two of them ARE the allowance and are asked for
      // under that name; the other two are not offered at all.
      else if (model.isAbstinence) ...<Widget>[
        _buildAllowanceRow(model, theme, l10n),
        _buildCommitmentBox(model, theme, l10n),
      ]
      else if (model.isNumerical) ...<Widget>[
```

14. В `_buildQuestionBox` заменить

```dart
        hintText: model.isSleep
            ? l10n.sleepQuestionExample
            : model.isNumerical
                ? l10n.measurableQuestionExample
                : l10n.exampleQuestionBoolean,
```

    на

```dart
        hintText: model.isSleep
            ? l10n.sleepQuestionExample
            : model.isAbstinence
                ? l10n.abstinenceQuestionExample
                : model.isNumerical
                    ? l10n.measurableQuestionExample
                    : l10n.exampleQuestionBoolean,
```

15. Добавить два билдера рядом с `_buildTargetRow`:

```dart
  /// The allowance and the unit it is counted in, side by side.
  ///
  /// The two controls the ordinary numerical form calls Target and Unit, asked
  /// as one question: how much may a day hold before it counts as a slip. They
  /// are the same two controllers, because for this kind they are the same two
  /// values — a person who writes 30 minutes has set `targetValue` and `unit`.
  /// What does not come along is the numerical frequency picker that shares
  /// this row upstream: an abstinence habit is scored every day, and no
  /// control on the form may say otherwise.
  Widget _buildAllowanceRow(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return IntrinsicHeight(
      key: EditHabitScreen.abstinenceAllowanceBoxKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _FormBox(
              label: l10n.abstinenceAllowance,
              theme: theme,
              child: _FormInput(
                key: EditHabitScreen.abstinenceAllowanceFieldKey,
                controller: model.targetController,
                theme: theme,
                hintText: l10n.abstinenceAllowanceExample,
                errorText: _errorTextOf(model.allowanceError, l10n),
                maxLines: 1,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),
          Expanded(
            child: _FormBox(
              label: l10n.abstinenceAllowanceUnit,
              theme: theme,
              child: _FormInput(
                key: EditHabitScreen.abstinenceUnitFieldKey,
                controller: model.unitController,
                theme: theme,
                hintText: l10n.abstinenceAllowanceUnitExample,
                maxLines: 1,
                // Same reason as the ported unit input: "minutes", lower case,
                // is what the list subtitle renders next to the number
                // (`audit4.the-unit-field-auto-capitalizes-which#1`).
                textCapitalization: TextCapitalization.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The day the person committed.
  Widget _buildCommitmentBox(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return _FormBox(
      key: EditHabitScreen.abstinenceCommittedBoxKey,
      label: l10n.abstinenceCommittedFrom,
      theme: theme,
      child: _FormDropdown(
        key: EditHabitScreen.abstinenceCommittedPickerKey,
        theme: theme,
        text: IntlLocalDateFormatter.of(context)
            .longFormat(core.LocalDate(model.committedFrom)),
        onTap: _onPickCommitmentDay,
      ),
    );
  }

  /// Backwards only.
  ///
  /// Clean days are counted from this day rather than from the first slip, so
  /// a person who stopped six weeks ago can say so and the six weeks exist.
  /// Forward is refused by `lastDate`, and refused again in the model: the
  /// picker is one of three ways this value gets set.
  Future<void> _onPickCommitmentDay() async {
    final model = context.read<EditHabitModel>();
    final core.LocalDate today = core.getToday();
    final DateTime? picked = await _dismissCurrentAndShow<DateTime>(
      () => showDatePicker(
        context: context,
        initialDate: _asDateTime(core.LocalDate(model.committedFrom)),
        firstDate: DateTime(2000, 1, 1),
        lastDate: _asDateTime(today),
      ),
    );
    if (picked == null) return;
    model.setCommittedFrom(
      core.LocalDate.ymd(picked.year, picked.month, picked.day).daysSince2000,
    );
  }

  /// A [core.LocalDate] as the local midnight `showDatePicker` compares by.
  static DateTime _asDateTime(core.LocalDate date) =>
      DateTime(date.year, date.month, date.day);
```

16. `flutter test test/ui/abstinence/ test/ui/habits/edit/ test/ui/sleep/` —
    зелено.

17. Коммит: `create: the abstinence form — allowance, unit, commitment day`.

**Мутация:** в шаге 8 убрать `habit.targetType = NumericalHabitType.atMost;`
— упадёт `computed.create#6` (`atLeast` вместо `atMost`). Убрать
`habit.frequency = Frequency(1, 1);` — упадёт проверка знаменателя (по
умолчанию `freqDen = 1`, поэтому проверять надо оба числа, и тест их проверяет
оба). В шаге 7 заменить `!isComputed` обратно на `!isSleep` — упадёт
`computed.create#5` («сохраняется с одним именем»: пустая цель даст
`EditHabitFieldError.blank`). В шаге 4 убрать `targetController.text = '0';`
— упадёт «the allowance starts at zero». В шаге 6 снять кламп — упадёт
`setCommittedFrom(9001)`. В шаге 13 поставить ветку `isAbstinence` **после**
`isNumerical` — упадут все четыре `findsNothing` из шага 10.

---

### Task 29: строка определения на сохранении (5-create.5)

Определение пишется тем же способом, что и цель сна, — слушателем
`CommandRunner`, а не строкой после `run`: команда идёт через task runner, и на
устройстве привычки в списке ещё нет, когда `save()` возвращает управление.
Заодно этот слушатель перестаёт быть сонным: у него появляется второй житель.

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/edit_habit_model.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_test.dart`

**Interfaces:**
- Consumes: `DefinitionRepository.save(int habitId, HabitDefinition definition)`, `HabitDefinition({required ComputedKind kind, int? committedFrom, Map<String, Object?> payload})`
- Consumes: `abstinencePayload`, `abstinenceAllowanceOf`, `abstinenceUnitCount`
  (Задача 2) и `attachDefinition` (Задача 17).
- Produces: строка `HabitDefinitions` вида `abstinence` с
  `committed_from = EditHabitModel.committedFrom` и payload, собранным
  **хелпером ядра**, а не литералами: ключи названы один раз, и пустая единица
  сама становится `abstinenceUnitCount`.
  **Читателям:** звать `abstinenceAllowanceOf(definition)` — он отдаёт `double`
  и переживает и `30`, и `30.0`, и `0.5`; `unit` — `abstinenceUnitOf(definition)`.
  **Единственный судья допуска — `Habit.targetValue`**: payload хранит его
  затем, чтобы редактор показал допуск при повторном открытии, а всякое
  вычисление читает `targetValue`. Обе записи ставит один `save()`
  (`computed.allowance#1`).

**Шаги:**

1. Дописать в `app/test/ui/abstinence/abstinence_editor_test.dart`:

```dart
  group('the definition row', () {
    test('is written with the day and the allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.unitController.text = 'minutes';
      model.setCommittedFrom(8960);
      expect(model.save(), isTrue, reason: 'computed.create#7');

      final Habit habit = scope.habitList.getByPosition(0);
      final HabitDefinition? definition =
          scope.definitions.forHabit(habit.id!);
      expect(definition, isNotNull, reason: 'computed.create#7');
      expect(definition!.kind, ComputedKind.abstinence,
          reason: 'computed.create#7 — the row is what makes a habit '
              'computed; without it nothing outside the app is kept away '
              'from its days');
      expect(definition.committedFrom, 8960,
          reason: 'computed.create#7 — the recompute range starts here, not '
              'at the oldest entry: there is no oldest entry while the habit '
              'is being kept');
      expect(abstinenceAllowanceOf(definition), 30.0,
          reason: 'computed.create#7');
      expect(abstinenceUnitOf(definition), 'minutes',
          reason: 'computed.create#7');
      expect(scope.definitions.isComputed(habit.id!), isTrue,
          reason: 'computed.create#7');
      // Настоящая цитата `computed.write-paths#5`: тип у привычки не тот, что
      // ей выставил тест, а тот, с которым её завёл редактор. Неохраняемая
      // дверь переключения да/нет живёт под `!habit.isNumerical`, и достать
      // воздержание она не может ровно потому, что вот эта строка зелёная.
      expect(habit.type, HabitType.numerical,
          reason: 'computed.write-paths#5 — вычисляемая привычка числовая по '
              'построению, и переключить её нечем');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'computed.create#7 — «не более допуска»');
    });

    test('the allowance in the row and the target on the habit are one number',
        () {
      // Две копии одного числа разъезжаются молча: `EditHabitCommand` может
      // изменить `targetValue`, не тронув payload. Их пишет один save, и это
      // проверяется, а не подразумевается.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.setCommittedFrom(8960);
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(abstinenceAllowanceOf(scope.definitions.forHabit(habit.id!)!),
          habit.targetValue,
          reason: 'computed.allowance#1 — допуск назван один раз, иначе '
              'вчерашний день судится вчерашним правилом');
    });

    test('the default habit gets a row too, with today and no allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.save();

      final HabitDefinition definition = scope.definitions
          .forHabit(scope.habitList.getByPosition(0).id!)!;
      expect(definition.committedFrom, 9000, reason: 'computed.create#8');
      expect(abstinenceAllowanceOf(definition), 0.0,
          reason: 'computed.create#5 — zero allowance means one tap is a slip');
      expect(definition.payload['unit'], abstinenceUnitCount,
          reason: 'computed.create#5 — единица названа один раз, и пустая '
              'строка в базу не уезжает (`computed.allowance#2`)');
    });

    test('an ordinary habit gets no row on this path', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, habitType: HabitType.numerical);
      model.nameController.text = 'Pages';
      model.unitController.text = 'pages';
      model.targetController.text = '30';
      model.save();

      expect(scope.definitions.forHabit(scope.habitList.getByPosition(0).id!),
          isNull,
          reason: 'computed.create#10 — an ordinary habit is not made '
              'computed by any path of this editor');
    });
  });

  group('on a device, not in a harness', () {
    /// A scope on the dispatchers production uses: a command handed to the
    /// real task runner has NOT run when `save()` returns.
    AppScope asyncScope() {
      final AppScope s = AppScope.open(database);
      addTearDown(s.close);
      return s;
    }

    test('the definition is stored even though the command has not run yet',
        () async {
      final AppScope real = asyncScope();
      final EditHabitModel model =
          EditHabitModel(scope: real, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      expect(model.save(), isTrue, reason: 'computed.create#9');

      await pumpEventQueue(times: 20);

      expect(real.habitList.size(), 1, reason: 'computed.create#9');
      final Habit habit = real.habitList.getByPosition(0);
      expect(real.definitions.forHabit(habit.id!)?.kind,
          ComputedKind.abstinence,
          reason: 'computed.create#9 — reading the command\'s result on the '
              'next line works in every test and silently does nothing on a '
              'phone');
    });
  });
```

2. `flutter test test/ui/abstinence/abstinence_editor_test.dart` — падает:
   `Expected: not null  Actual: <null>` на `expect(definition, isNotNull)`
   (`computed.create#7`).

3. В `app/lib/state/edit_habit_model.dart` обобщить слушателя. Заменить хвост
   `save()` — было:

```dart
    final SleepGoal? goal = sleepGoal;
    if (goal != null) {
      scope.commandRunner.addListener(
        _SleepGoalWriter(
          scope: scope,
          command: command,
          habitId: habitId,
          uuid: habit.uuid,
          goal: goal,
        ),
      );
    }
```

   стало:

```dart
    // The side rows a computed habit needs are written once the command has
    // actually run, not on the next line. `CommandRunner.run` hands the
    // command to a task runner; the dispatcher a test uses executes it at
    // once, the one a device uses does not.
    final SleepGoal? goal = sleepGoal;
    if (goal != null) {
      scope.commandRunner.addListener(_AfterCommand(
        scope: scope,
        command: command,
        habitId: habitId,
        uuid: habit.uuid,
        apply: (AppScope scope, Habit saved) =>
            _writeSleepGoal(scope, saved, goal),
      ));
    } else if (isAbstinence) {
      // Payload собирается дверью ядра, а не литералами: ключи названы один
      // раз (`computed/abstinence_payload.dart`), тип допуска — `double`, и
      // пустая единица сама становится `count`.
      final HabitDefinition definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(
          allowance: double.tryParse(targetController.text) ?? 0,
          unit: unitController.text.trim(),
        ),
      );
      scope.commandRunner.addListener(_AfterCommand(
        scope: scope,
        command: command,
        habitId: habitId,
        uuid: habit.uuid,
        apply: (AppScope scope, Habit saved) {
          scope.definitions.save(saved.id!, definition);
          // Строка в базе и живая модель — разные вещи: пересчёт читает поле,
          // а не репозиторий (`computed.commitment#5`), и `attachDefinition`
          // заодно включает деление пополам (`computed.lapse-score#11`). Без
          // этих двух строк только что созданное воздержание до перезапуска
          // считалось бы с сегодняшнего дня и затуханием порта.
          attachDefinition(saved, scope.definitions);
          saved.recompute();
          scope.onComputedDataChanged(saved.id!);
        },
      ));
    }
```

4. В том же файле заменить класс `_SleepGoalWriter` целиком на общий слушатель
   плюс сонную функцию (тело сонной — прежнее, дословно):

```dart
/// Runs [apply] once the command that creates or edits its habit has finished.
///
/// A listener rather than a line after `run`: the command goes through a task
/// runner, so on a device the habit is not in the list yet when `save`
/// returns. It was written for the sleep goal and is now shared, which is what
/// a second computed kind is for.
class _AfterCommand implements CommandRunnerListener {
  _AfterCommand({
    required this.scope,
    required this.command,
    required this.habitId,
    required this.uuid,
    required this.apply,
  });

  final AppScope scope;
  final Command command;
  final int habitId;

  /// `CreateHabitCommand` keeps the form's habit as a template and builds its
  /// own, so that object never gets an id. The uuid is copied across, and is
  /// what identifies the one that did enter the list.
  final String? uuid;

  final void Function(AppScope scope, Habit saved) apply;

  bool _done = false;

  @override
  void onCommandFinished(Command finished) {
    if (_done || !identical(finished, command)) return;
    _done = true;
    // Removed on a microtask: `notifyListeners` is iterating the very list
    // this would mutate.
    scheduleMicrotask(() => scope.commandRunner.removeListener(this));

    // The command runs on a task runner, so this can arrive after the screen
    // and the scope behind it are gone.
    if (scope.isClosed) return;

    final Habit? saved =
        habitId >= 0 ? scope.habitList.getById(habitId) : _byUuid();
    if (saved?.id == null) return;
    apply(scope, saved!);
  }

  Habit? _byUuid() {
    final String? id = uuid;
    if (id == null) return null;
    for (final Habit habit in scope.habitList.toList()) {
      if (habit.uuid == id) return habit;
    }
    return null;
  }
}

/// Everything a sleep habit needs beside its row in `Habits`.
void _writeSleepGoal(AppScope scope, Habit saved, SleepGoal goal) {
  scope.sleepRepository.saveGoal(saved.id!, goal);
  // The goal is what sleep needs; the definition is what the app needs to know
  // there is anything to compute at all. Written together because a habit with
  // one and not the other is a habit half of the app can see.
  scope.definitions.save(
    saved.id!,
    const HabitDefinition(kind: ComputedKind.sleep),
  );
  // And onto the live model, not only into the database — the same two lines
  // abstinence needs, and the same hole without them: a habit created in this
  // session would compute by the ported window until the app restarts.
  attachDefinition(saved, scope.definitions);
  saved.recompute();
  // Changing a goal changes what every past night was worth. Rescoring only
  // from today would leave the history a mixture of two scales.
  scope.sleepSync.recomputeAll(saved);
  scope.onComputedDataChanged(saved.id!);
  // And a habit that has just become a sleep habit has never been synced:
  // without this it shows nothing until the app is backgrounded once.
  unawaited(scope.syncSleepHabits());
}
```

5. `flutter test test/ui/abstinence/ test/ui/sleep/ test/state/computed_sleep_pairing_test.dart test/state/sleep_sync_wiring_test.dart` — зелено.
   Сонные тесты обязаны пройти **без единой правки** — это и есть
   доказательство, что обобщение слушателя ничего не потеряло.

6. Коммит: `create: write the abstinence definition row on save`.

**Мутация:** в шаге 3 убрать `committedFrom: committedFrom,` — упадёт
`computed.create#7` (`null` вместо `8960`) и `computed.create#8`. Заменить
`abstinencePayload(...)` на литерал `<String, Object?>{'amount': …}` — упадёт
`abstinenceAllowanceOf`, вернув 0 вместо 30. Убрать
`attachDefinition(saved, scope.definitions);` — упадёт тест «the habit is
computing from the moment it is saved» из Задачи 30. В `save()` записать
`habit.targetValue = 0` вместо разбора поля — упадёт «the allowance in the row
and the target on the habit are one number». Заменить слушателя на прямой
вызов `scope.definitions.save(...)` сразу после `commandRunner.run(command)` —
синхронные тесты останутся зелёными, а «on a device» упадёт: у привычки ещё
нет id. Это и есть его смысл. В шаге 4 убрать `if (scope.isClosed) return;` —
упадёт `tearDown` соседних сонных тестов на записи в закрытую базу.

---

### Task 30: режим редактирования и невозможность смены вида (5-create.6)

**Files:**
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_test.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/abstinence/abstinence_editor_screen_test.dart`
- Modify (если тесты потребуют): `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/edit_habit_model.dart`

**Interfaces:** ничего нового не производит — закрепляет поведение
Task 5-create.1 (шаг 5) и Task 5-create.4 (шаг 5).

**Шаги:**

1. Дописать в `app/test/ui/abstinence/abstinence_editor_test.dart`:

```dart
  group('opening one that already exists', () {
    /// Creates an abstinence habit the way the editor does, and hands back its
    /// id.
    int makeOne({required String allowance, required int committedFrom}) {
      final EditHabitModel making =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      making.nameController.text = 'Screen time';
      making.targetController.text = allowance;
      making.unitController.text = 'minutes';
      making.setCommittedFrom(committedFrom);
      making.save();
      return scope.habitList.getByPosition(0).id!;
    }

    test('the kind comes from the definition row, not from a flag', () {
      final int id = makeOne(allowance: '30', committedFrom: 8960);

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      expect(editing.computedKind, ComputedKind.abstinence,
          reason: 'computed.create#10 — EDIT mode is never told the kind; the '
              'row is the only thing that knows');
      expect(editing.isAbstinence, isTrue, reason: 'computed.create#10');
      expect(editing.committedFrom, 8960, reason: 'computed.create#10');
      expect(editing.targetController.text, '30',
          reason: 'computed.create#10 — "30", not "30.0": an allowance is a '
              'count of minutes and that is how it was typed in');
      expect(editing.unitController.text, 'minutes',
          reason: 'computed.create#10');
    });

    test('changing the allowance updates the row instead of adding one', () {
      final int id = makeOne(allowance: '30', committedFrom: 8960);

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      editing.targetController.text = '10';
      editing.setCommittedFrom(8950);
      expect(editing.save(), isTrue, reason: 'computed.create#10');

      final HabitDefinition definition = scope.definitions.forHabit(id)!;
      expect(definition.kind, ComputedKind.abstinence,
          reason: 'computed.create#10 — the kind does not move');
      expect((definition.payload['allowance'] as num).toDouble(), 10.0,
          reason: 'computed.create#10');
      expect(definition.committedFrom, 8950, reason: 'computed.create#10');
      expect(scope.habitList.getById(id)!.targetValue, 10.0,
          reason: 'computed.create#6 — the habit and the row are written by '
              'the same save, so they cannot drift apart');
    });

    test('the habit is computing from the moment it is saved', () {
      // Строка в базе — половина дела: пересчёт читает `Habit.definition`, а
      // не репозиторий. Без прикрепления на живой модели только что созданное
      // воздержание до перезапуска считается с сегодняшнего дня, деление
      // пополам выключено, а «сорока дней» не существует. Тесты выше этого не
      // видят: они проверяют базу, а не модель.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.setCommittedFrom(8960);
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.definition?.committedFrom, 8960,
          reason: 'computed.commitment#5 — без перезапуска');
      expect(habit.scores.halvesOnLapse, isTrue,
          reason: 'computed.lapse-score#11');
      expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');
    });

    test('an ordinary habit opened for editing never becomes computed', () {
      final EditHabitModel making =
          EditHabitModel(scope: scope, habitType: HabitType.numerical);
      making.nameController.text = 'Pages';
      making.unitController.text = 'pages';
      making.targetController.text = '30';
      making.save();
      final int id = scope.habitList.getByPosition(0).id!;

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      expect(editing.computedKind, isNull, reason: 'computed.create#10');
      expect(editing.isComputed, isFalse, reason: 'computed.create#10');
      editing.targetController.text = '40';
      editing.save();

      expect(scope.definitions.forHabit(id), isNull,
          reason: 'computed.create#10 — the transition ordinary → computed '
              'does not exist, and it does not exist because there is no code '
              'for it in either direction, not by agreement');
      expect(scope.definitions.isComputed(id), isFalse,
          reason: 'computed.create#10');
    });
  });
```

2. Дописать в `app/test/ui/abstinence/abstinence_editor_screen_test.dart`:

```dart
  testWidgets('the chooser is nowhere on the editor itself', (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    for (final Key key in <Key>[
      EditHabitScreen.yesNoTypeCardKey,
      EditHabitScreen.measurableTypeCardKey,
      EditHabitScreen.sleepTypeCardKey,
      EditHabitScreen.abstinenceTypeCardKey,
    ]) {
      expect(find.byKey(key), findsNothing,
          reason: 'computed.create#10 — there is no control for the kind on '
              'the form, which is why the kind cannot change');
    }
  });
```

3. `flutter test test/ui/abstinence/` — прогнать. Ожидаемо всё зелено: код
   написан в Task 5-create.1 и .4. Если что-то падает — чинить там, где
   написано, а не здесь.

4. Коммит: `create: pin the abstinence editor's EDIT mode`.

**Мутация:** в Задаче 29 убрать `attachDefinition(saved, scope.definitions);`
из `apply` — упадёт «the habit is computing from the moment it is saved» на
`habit.definition?.committedFrom` (`null` вместо `8960`); убрать оттуда же
`saved.recompute();` — упадёт `daysWithoutLapse(habit)` (ноль вместо сорока).
В Задаче 25 (шаг 5) убрать `computedKind = definition?.kind;` — упадёт «the kind
comes from the definition row». В Task 5-create.4 (шаг 5) убрать переформатирование допуска — упадёт
`expect(editing.targetController.text, '30')` (получит `'30.0'`). Заменить в
`save()` условие `else if (isAbstinence)` на `else if (habitId < 0 &&
isAbstinence)` — упадёт «changing the allowance updates the row». Написать в
`save()` определение безусловно (без `isAbstinence`) — упадёт «an ordinary
habit opened for editing never becomes computed».

---

### Task 31: взвести реестр и сверить покрытие (5-create.7)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`

**Шаги:**

1. `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && dart tool/parity_coverage.dart --uncited | grep computed.create`
   — вывод должен быть пуст: все одиннадцать правил процитированы.

2. Заменить в `docs/extensions/COMPUTED.md` строку `- [ ] \`computed.create\``
   на `- [x] \`computed.create\``.

3. `dart tool/parity_coverage.dart --verify` — код возврата 0.

4. `cd app && flutter test` — весь набор зелёный. Отдельно убедиться, что
   `test/models/palette_color_test.dart` и
   `packages/uhabits_core/test/sleep/stored_value_test.dart` (оба про
   двухэлементность перечислений) прошли **без правок**: четвёртая карточка не
   добавила третьего `HabitType`.

5. Коммит: `create: close computed.create in the ledger`.

**Мутация:** снять `[x]` — `--verify` останется зелёным (невзведённые фичи он
не проверяет), поэтому шаг 1 делается до шага 2 и его вывод — часть
доказательства. Убрать цитату `computed.create#11` из теста «a blank allowance
is zero» — шаг 1 напечатает `computed.create#11`, шаг 3 вернёт 1.

## Раздел «Ячейка списка и экран привычки-воздержания»


Что решает эта секция: воздержание — **числовая** привычка, значит сегодня её
строка в списке рисует число («0» серым в каждой ячейке) и по тапу просит ввести
значение, а вычисляемой привычке ввод запрещён (`computed.write-paths#3`). Здесь
описано, что рисуется вместо числовой панели, как тап пишет срыв, не проходя
мимо запрета, и что показывает экран самой привычки.

### Что этот раздел потребляет от предыдущих

Ровно шесть имён. Ничего больше из ядра воздержания UI не знает.

```dart
// AppScope (app/lib/state/app_scope.dart), Задача 10:
void onComputedDataChanged(int habitId);   // обобщённый hook 4 (был onSleepDataChanged)

// AppScope.lapses -> LapseRepository, Задачи 3 и 19:
int? lastDay(int habitId);                 // null, если срывов не было

// AppScope.abstinence -> AbstinenceSync, Задача 24:
void setLapse(core.Habit habit, core.LocalDate date, bool lapsed, {int? amount});

// package:uhabits_core/uhabits_core.dart, Задача 16:
int daysWithoutLapse(core.Habit habit, {core.LocalDate? asOf});

// package:uhabits_core/uhabits_core.dart, Задача 2 — СУДЬЯ СРЫВА:
bool isAbstinenceLapse(core.HabitDefinition definition, num amount);
double abstinenceAllowanceOf(core.HabitDefinition definition);
```

Контракт `setLapse`, на который здесь опирается всё остальное:

1. идемпотентен — `setLapse(h, d, true)` дважды даёт один срыв;
2. пишет журнал **и** пересчитывает день через `DayWriter`;
3. значение записанного дня есть величина × 1000, то есть **строго больше 3**
   (минимум — одна единица = 1000); день, о котором ничего не записано, не
   пишется вовсе (`computed.day-write#3`);
4. на день с пропуском `DayWriter` не пишет ничего — поэтому ячейка-пропуск
   здесь не нажимается.

Пункт 3 говорит «записанного дня», а не «дня-срыва», и разница существенна с
того момента, как допуск перестал быть нулём: при допуске 30 запись «20 минут»
в дне есть, а срыва нет. Журнал хранит **замер**, срывом его называет
`isAbstinenceLapse(definition, величина)` — и называет заново каждый раз, когда
спрашивают (`computed.allowance#1`). Отсюда и правило интерфейса: рисует,
считает и подписывает всё тот же предикат, а не «есть ли в дне запись».

`daysWithoutLapse` потребляется **ядровая**, и своей копии в приложении нет.
Функций с этим именем было две — в ядре и здесь, — и на одних данных они давали
разные числа; кроме того, `abstinence_screen_test.dart` импортирует и бочку без
префикса, и файл счётчика, то есть две top-level функции попали бы в одну
область видимости (`Error: 'daysWithoutLapse' is imported from both`).
Осталась ядровая: она единственная переживает «срыв в будущем» и не требует
второго запроса к журналу. Семантика — прошедшее время: день обязательства даёт
ноль, «сорок чистых дней» есть `committedFrom.daysUntil(today)`. Приложение
берёт из журнала только **подпись** под счётчиком: `lastDay` решает, писать
«С {дата}» или «Последний срыв: {дата}».

### Что секция производит

```dart
// app/lib/ui/habits/abstinence/abstinence_button_view.dart
enum AbstinenceCell { beforeCommitment, clean, lapse, skipped }
bool isAbstinenceLapseDay(core.HabitDefinition definition, int storedValue);
AbstinenceCell abstinenceCellOf({required core.HabitDefinition definition, required int storedValue, required int day});
class AbstinenceButtonView extends core.View { ... }

// app/lib/ui/habits/abstinence/abstinence_gestures.dart
void setLapseDay(AppScope scope, {required core.Habit habit, required core.LocalDate date, required bool lapsed, int? amount});
Future<bool> toggleLapseDay(BuildContext context, AppScope scope, {required core.Habit habit, required core.HabitDefinition definition, required core.LocalDate date, required bool lapsed, required core.Theme theme});

// app/lib/ui/habits/abstinence/abstinence_amount_dialog.dart
Future<int?> askLapseAmount(BuildContext context, {required core.HabitDefinition definition, required core.Preferences preferences, required core.Color color});

// app/lib/ui/habits/abstinence/abstinence_section.dart
List<Widget> buildAbstinenceSection(BuildContext context, {required AppScope scope, required core.Habit habit, required core.HabitDefinition definition, required core.Theme theme, required VoidCallback onChanged});

// app/lib/ui/habits/list/entry_panel.dart
typedef EntryLapseCallback = Future<bool> Function(core.LocalDate date, bool lapsed);
// EntryPanel/HabitCard: + final core.HabitDefinition? abstinenceDefinition; + final EntryLapseCallback? onLapse;

// app/lib/state/habit_list_model.dart
core.HabitDefinition? abstinenceDefinitionOf(core.Habit habit);
```

### Опорное решение: признаком воздержания в UI служит `committedFrom`

Воздержание — числовая привычка, `isNumerical` её ни от чего не отличает. Ячейку
переключает **непустой `committed_from` у определения вида `abstinence`**, а не
сам вид. Причины:

* судить день «чистый или сорванный» не от чего, пока не известен день обещания:
  чистыми оказались бы все дни от начала времён;
* спека называет `committed_from` обязательным для воздержания;
* два уже зелёных теста (`app/test/ui/habits/list/computed_list_edit_test.dart`,
  `app/test/ui/sleep/calendar_editor_guard_test.dart`) сохраняют определение
  `HabitDefinition(kind: ComputedKind.abstinence)` **без** `committedFrom` и
  проверяют, что жест упирается в общий отказ. С этим признаком они остаются
  зелёными дословно, а неполное определение ведёт себя как любая другая
  вычисляемая привычка: числовое окно не открывается, ничего не пишется.

**Едет вниз, однако, всё определение целиком, а не один день обещания.** Признак
остаётся прежним — вид `abstinence` **и** непустой `committed_from`, — но
считает его поставщик (`HabitListModel.abstinenceDefinitionOf`,
`ShowHabitScreen._abstinenceDefinition`), а ячейке, кнопке и календарю
передаётся `HabitDefinition?`. Причина одна: судья срыва —
`isAbstinenceLapse(definition, величина)`, и допуск он берёт из определения.
Довезти до ячейки только день обещания значит оставить ей своё суждение о
срыве — а своего у неё быть не должно. `null` по-прежнему означает «это не
воздержание», и обе ветки, и оба зелёных теста выше, остаются дословно теми же.

### Task 32: правила и строки интерфейса (4-ui-list.1)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/l10n/localization_inventory_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/l10n/app_en.arb`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/l10n/app_ru.arb`
- Generated: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/l10n/app_localizations*.dart`

**Interfaces:** Consumes — ничего. Produces — `L10n.abstinenceTitle`,
`L10n.abstinenceCleanDaysLabel(num days)`, `L10n.abstinenceSince(String date)`,
`L10n.abstinenceLastLapse(String date)`, `L10n.abstinenceLapseToday`,
`L10n.abstinenceUndoToday`; правила `computed.abstinence-cell#1..#8`,
`computed.abstinence-screen#1..#6`.

Строк ровно шесть, и восьмое правило ячейки новых не приносит: ввод величины
строится на портированном числовом диалоге и берёт его надписи («Сохранить»,
«Заметки») как есть. Число `14` в инвентаре локализации от этой задачи не
меняется.

1. Дописать в конец `docs/extensions/COMPUTED.md` две группы. Пока `- [ ]`:
   `--verify` требует цитат только с закрытых групп, и флажок ставится в
   последней задаче секции.

```markdown
- [ ] `computed.abstinence-cell`
1. `computed.abstinence-cell#1` День без записи рисуется удачным: полая галочка, а не «0» и не вопрос.
2. `computed.abstinence-cell#2` Крестом рисуется день, который есть срыв по тому же судье, что и оценка: величина дня больше допуска, `isAbstinenceLapse(definition, величина)` (`computed.lapse-score#5`, `computed.allowance#3`). При допуске ноль это любая записанная величина; при допуске 30 — только большая тридцати, а тридцать и меньше рисуются галочкой. Своего порога у интерфейса нет.
3. `computed.abstinence-cell#3` День до дня обязательства пуст и не нажимается: приложение не приписывает себе дни до обещания.
4. `computed.abstinence-cell#4` Пропуск остаётся пропуском и не переводится тапом в срыв: вычисленное значение не затирает отметку человека.
5. `computed.abstinence-cell#5` Тап по ячейке записывает срыв за этот день, повторный тап его снимает.
6. `computed.abstinence-cell#6` Ни тап, ни долгое нажатие не открывают числовое окно и не пишут значение дня напрямую.
7. `computed.abstinence-cell#7` Определение без дня обязательства не превращает ячейку в воздержание: привычка остаётся числовой и упирается в общий отказ.
8. `computed.abstinence-cell#8` Величину спрашивают ровно тогда, когда допуск её требует: при допуске ноль тап пишет одну единицу и лишнего шага нет, при допуске больше нуля тап спрашивает «сколько сегодня» и без ответа не пишет ничего. Снятие срыва величины не спрашивает никогда.

- [ ] `computed.abstinence-screen`
1. `computed.abstinence-screen#1` Экран воздержания показывает то число, которое отдаёт ядровая `daysWithoutLapse`, и подпись «С {дата}» под ним, пока срывов не было. Арифметику счёта держит `computed.streak#4`, а не это правило.
2. `computed.abstinence-screen#2` После срыва подпись меняется на «Последний срыв: {дата}», а число идёт за `daysWithoutLapse` — срыв сегодня даёт ноль (`computed.streak#5`).
3. `computed.abstinence-screen#3` Счётчик стоит выше портированных карточек: это и есть привычка, а не её механика.
4. `computed.abstinence-screen#4` Карточка цели скрыта, кольцо Overview показано — как у сна.
5. `computed.abstinence-screen#5` Кнопка на карточке пишет и снимает срыв за сегодня, и её надпись меняется вместе с днём.
6. `computed.abstinence-screen#6` Тап по дню в календаре-редакторе записывает срыв за этот день вместо числового окна.
```

2. Дописать в `app/lib/l10n/app_en.arb` перед закрывающей скобкой:

```json
  "abstinenceTitle": "Without a lapse",
  "abstinenceCleanDaysLabel": "{days, plural, one {day without a lapse} other {days without a lapse}}",
  "@abstinenceCleanDaysLabel": {
    "description": "Label beside the big counter on an abstinence habit's screen.",
    "placeholders": {
      "days": {
        "type": "num"
      }
    }
  },
  "abstinenceSince": "Since {date}",
  "@abstinenceSince": {
    "description": "The day the person committed, shown when they have never lapsed.",
    "placeholders": {
      "date": {
        "type": "String"
      }
    }
  },
  "abstinenceLastLapse": "Last lapse: {date}",
  "@abstinenceLastLapse": {
    "placeholders": {
      "date": {
        "type": "String"
      }
    }
  },
  "abstinenceLapseToday": "I lapsed today",
  "abstinenceUndoToday": "Undo today"
```

3. Дописать в `app/lib/l10n/app_ru.arb` (метаданные `@` живут только в шаблоне):

```json
  "abstinenceTitle": "Без срывов",
  "abstinenceCleanDaysLabel": "{days, plural, one {день без срыва} few {дня без срыва} many {дней без срыва} other {дня без срыва}}",
  "abstinenceSince": "С {date}",
  "abstinenceLastLapse": "Последний срыв: {date}",
  "abstinenceLapseToday": "Сегодня сорвался",
  "abstinenceUndoToday": "Отменить за сегодня"
```

4. Поправить единственное буквальное число в инвентаре локализации. В
`app/test/l10n/localization_inventory_test.dart` (фильтр `extensionPrefixes`
там уже расширен Задачей 26) заменить

```dart
      expect(extension.where((String k) => k.startsWith('abstinence')).length,
          8,
          reason: 'platform-glue.localization-inventory#4 (deviation) — the '
              'abstinence editor adds exactly eight strings, and a ninth that '
              'nobody declared would be one nobody translated');
```

на

```dart
      expect(extension.where((String k) => k.startsWith('abstinence')).length,
          14,
          reason: 'platform-glue.localization-inventory#4 (deviation) — the '
              'abstinence kind adds exactly fourteen strings: eight in the '
              'editor and six on the list cell and the habit screen. A '
              'fifteenth that nobody declared would be one nobody translated');
```

Число остаётся буквальным — в этом его смысл. Прогнать
`flutter test test/l10n/`: зелено. Мутация — вернуть `14` на `8`: падает
`platform-glue.localization-inventory#4` с `Expected: <8> Actual: <14>`.

5. Сгенерировать словари и убедиться, что русский действительно попал в код:

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter gen-l10n
grep -n "abstinenceUndoToday\|abstinenceTitle" lib/l10n/app_localizations_ru.dart
```

Ожидается `String get abstinenceTitle => 'Без срывов';` — не английская строка.
Строки сна однажды уехали на телефон непереведёнными, и владелец не нашёл
фичу; этот `grep` — та проверка, которой тогда не было.

6. Коммит: `l10n: строки привычки-воздержания (en, ru)`.

---

### Task 33: рисунок ячейки (4-ui-list.2)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_button_view.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/abstinence/abstinence_button_view_test.dart`

**Interfaces:** Consumes — `core.View`, `core.Canvas`, `core.FontAwesome`,
`core.Entry`, `core.HabitDefinition` и `core.isAbstinenceLapse` (Задача 2), и из
`ui/habits/list/entry_button_views.dart` уже публичные `drawNotesIndicator`,
`smallTextSize`, `yesAutoTextSize`, `yesAutoStrokeWidth`.
Produces — `enum AbstinenceCell`,
`bool isAbstinenceLapseDay(core.HabitDefinition definition, int storedValue)`,
`AbstinenceCell abstinenceCellOf({required core.HabitDefinition definition, required int storedValue, required int day})`,
`class AbstinenceButtonView extends core.View` с чистыми геттерами
`String? get glyph`, `core.Color get glyphColor`, `bool get isHollow`,
`double get fontSize`.

**Опорное решение: судья один, и он не свой.** Срывом день называет
`isAbstinenceLapse(definition, величина)` из Задачи 2 — тот самый предикат, по
которому судит оценка. Своего порога у интерфейса нет и быть не может: «не более
30 минут» на ячейке и «не более 30 минут» в балле обязаны означать одно, а два
предиката расходятся молча и расходятся не сразу.

Предикат берёт **величину**, а ячейке приходит хранимое значение дня — величина
× 1000 (`computed.lapse-score#2`). Перевод шкалы записан один раз, в
`isAbstinenceLapseDay`, и это единственное, что тот добавляет: он не второй
судья, а первый, переведённый в единицы дня. Прежнего
`isLapseValue(stored) => stored > Entry.skip` в роли судьи нет нигде — он давал
«срыв» на величине 1 при допуске 30, то есть красил крестом день, который
обещание держал, и не совпадал ни со счётчиком дней, ни с баллом.

1. Сначала тест. Создать
`app/test/ui/habits/abstinence/abstinence_button_view_test.dart`:

```dart
/// Ячейка списка привычки-воздержания.
///
/// Вид — чистая функция от состояния дня, поэтому проверяется через геттеры,
/// как `entry_button_views_test.dart` проверяет цвет глифа: холст ничего к
/// решению не добавляет.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final core.Theme theme = core.LightTheme();
  final core.Color habitColor = theme.colorOf(const core.PaletteColor(7));

  /// Обязательство с допуском — то самое, по которому судит и оценка.
  core.HabitDefinition commitment({double allowance = 0.0, int from = 10}) =>
      core.HabitDefinition(
        kind: core.ComputedKind.abstinence,
        committedFrom: from,
        payload: core.abstinencePayload(
          allowance: allowance,
          unit: allowance == 0.0
              ? core.abstinenceUnitCount
              : core.abstinenceUnitMinutes,
        ),
      );

  AbstinenceButtonView view(AbstinenceCell cell) => AbstinenceButtonView(
        cell: cell,
        color: habitColor,
        theme: theme,
      );

  test('computed.abstinence-cell#1 день без записи выглядит удачным', () {
    // Сегодня, вчера, день за пределами прочитанного окна: везде тишина.
    for (final int stored in <int>[core.Entry.unknown, -1, 0]) {
      expect(
        abstinenceCellOf(
            definition: commitment(), storedValue: stored, day: 100),
        AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#1 — молчание есть успех, '
            'stored=$stored',
      );
    }
    expect(view(AbstinenceCell.clean).glyph, core.FontAwesome.check,
        reason: 'computed.abstinence-cell#1');
    expect(view(AbstinenceCell.clean).glyphColor, habitColor,
        reason: 'computed.abstinence-cell#1');
    expect(view(AbstinenceCell.clean).isHollow, isTrue,
        reason: 'computed.abstinence-cell#1 — полая галочка: день зачло '
            'приложение, а не человек');
  });

  test('computed.abstinence-cell#2 крестом рисуется превышение допуска', () {
    // Допуск ноль — умолчание: любая записанная величина есть срыв. Значение
    // дня несёт величину × 1000.
    for (final int stored in <int>[1000, 30000]) {
      expect(
        abstinenceCellOf(
            definition: commitment(), storedValue: stored, day: 100),
        AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2 — stored=$stored при допуске 0',
      );
    }

    // Допуск 30: тридцать минут обещание держат, тридцать одна — нет. Ровно
    // та граница, по которой судит оценка (`computed.lapse-score#5`), и
    // прежний `stored > Entry.skip` назвал бы срывом все три.
    final core.HabitDefinition lenient = commitment(allowance: 30.0);
    expect(
        abstinenceCellOf(
            definition: lenient, storedValue: 29000, day: 100),
        AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2');
    expect(
        abstinenceCellOf(
            definition: lenient, storedValue: 30000, day: 100),
        AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более допуска» обещание '
            'держит');
    expect(
        abstinenceCellOf(
            definition: lenient, storedValue: 31000, day: 100),
        AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');

    expect(view(AbstinenceCell.lapse).glyph, core.FontAwesome.times,
        reason: 'computed.abstinence-cell#2');
    expect(view(AbstinenceCell.lapse).isHollow, isFalse,
        reason: 'computed.abstinence-cell#2');
  });

  test('computed.abstinence-cell#2 судья тот же, что у оценки', () {
    // `isAbstinenceLapseDay` не второй предикат, а первый, переведённый со
    // шкалы дня: значение дня есть величина × 1000, а `isAbstinenceLapse`
    // берёт величину. Расхождение здесь означало бы, что ячейка и балл
    // считают срывы по-разному.
    final core.HabitDefinition lenient = commitment(allowance: 30.0);
    for (final int amount in <int>[1, 20, 29, 30, 31, 45]) {
      expect(isAbstinenceLapseDay(lenient, amount * 1000),
          core.isAbstinenceLapse(lenient, amount),
          reason: 'computed.abstinence-cell#2 — интерфейс и оценка судят одним '
              'сравнением (`computed.lapse-score#5`), amount=$amount');
    }
  });

  test('computed.abstinence-cell#3 до дня обязательства ячейка пуста', () {
    expect(
      abstinenceCellOf(
          definition: commitment(), storedValue: core.Entry.unknown, day: 9),
      AbstinenceCell.beforeCommitment,
      reason: 'computed.abstinence-cell#3',
    );
    expect(
      abstinenceCellOf(
          definition: commitment(), storedValue: core.Entry.unknown, day: 10),
      AbstinenceCell.clean,
      reason: 'computed.abstinence-cell#3 — сам день обещания уже считается',
    );
    expect(view(AbstinenceCell.beforeCommitment).glyph, isNull,
        reason: 'computed.abstinence-cell#3 — рисовать нечего');
  });

  test('computed.abstinence-cell#4 пропуск остаётся пропуском', () {
    expect(
      abstinenceCellOf(
          definition: commitment(), storedValue: core.Entry.skip, day: 100),
      AbstinenceCell.skipped,
      reason: 'computed.abstinence-cell#4',
    );
    expect(view(AbstinenceCell.skipped).glyph, core.FontAwesome.skipped,
        reason: 'computed.abstinence-cell#4');
    // Ступеньки 1 и 2 занял бы человек; вычисленному значению туда нельзя, и
    // сюда они попасть не могут — но если попадут, это не срыв. Делить их на
    // тысячу нельзя: при допуске ноль `yesAuto` дал бы 0.001 и стал бы
    // «срывом» — отметка человека, прочитанная как замер.
    for (final int stored in <int>[core.Entry.yesAuto, core.Entry.yesManual]) {
      expect(isAbstinenceLapseDay(commitment(), stored), isFalse,
          reason: 'computed.abstinence-cell#4 — stored=$stored');
    }
  });
}
```

2. Запустить, увидеть падение по имени:

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/ui/habits/abstinence/abstinence_button_view_test.dart
```

Ожидается `Error: Couldn't resolve the package 'uhabits/ui/habits/abstinence/abstinence_button_view.dart'` — файла ещё нет.

3. Создать `app/lib/ui/habits/abstinence/abstinence_button_view.dart`:

```dart
/// Ячейка списка для привычки-воздержания.
///
/// Воздержание — числовая привычка, и числовая панель нарисовала бы ей «0» в
/// каждый день: величина, которой человек не вводил, в цвете «мимо цели». Тут
/// рисуется другое: день без записи выглядит удачным, потому что он удачный —
/// молчание и есть успех.
///
/// Словарь взят у порта, а не выдуман: чистый день есть полая галочка, то
/// самое начертание, которым `CheckmarkButtonView` рисует `YES_AUTO` — «зачло
/// приложение, человек ничего не подтверждал». Срыв есть крест в contrast60,
/// как порт рисует `NO` при включённых вопросах. Пропуск — свой глиф порта.
library;

// Пути `src` — ровно как в entry_button_views.dart.
// ignore_for_file: implementation_imports

import 'package:flutter/painting.dart' show TextScaler;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../platform/flutter_canvas.dart' show TextOutlineCanvas;
import '../list/entry_button_views.dart'
    show drawNotesIndicator, smallTextSize, yesAutoStrokeWidth, yesAutoTextSize;

/// Что ячейка говорит про день.
enum AbstinenceCell { beforeCommitment, clean, lapse, skipped }

/// Был ли в этот день срыв — по тому же судье, что и у оценки.
///
/// Судья один на всю привычку: `isAbstinenceLapse(definition, величина)` из
/// `computed/abstinence_payload.dart`. Оценка сравнивает
/// `normalizedRollingSum > targetValue`, а `targetValue` есть зеркало допуска
/// (`computed.allowance#1`), то есть это буквально одно сравнение, записанное
/// дважды (`computed.lapse-score#5`). Своего порога у интерфейса нет: «не более
/// 30 минут» на ячейке и «не более 30 минут» в балле обязаны означать одно.
///
/// Всё, что добавляет эта функция, — перевод шкалы. Предикат берёт величину, а
/// сюда приходит хранимое значение дня, то есть величина × 1000
/// (`computed.lapse-score#2`).
///
/// Ступеньки 1, 2 и 3 заняты `yesAuto`, `yesManual` и `skip`, а тишина есть -1.
/// Ни одна из них не величина, и делить их на тысячу бессмысленно: при допуске
/// ноль `yesAuto` дал бы 0.001 и стал бы «срывом» — отметка человека,
/// прочитанная как замер. Поэтому они отсеиваются до сравнения, а не им.
bool isAbstinenceLapseDay(core.HabitDefinition definition, int storedValue) {
  if (storedValue == core.Entry.unknown ||
      storedValue == core.Entry.skip ||
      storedValue == core.Entry.yesAuto ||
      storedValue == core.Entry.yesManual) {
    return false;
  }
  return core.isAbstinenceLapse(definition, storedValue / 1000.0);
}

/// Состояние дня по определению привычки и хранимому значению.
///
/// День обязательства спрашивается у определения, а не приезжает отдельным
/// числом: определение и так здесь, а два источника одного факта расходятся.
/// Пустой `committedFrom` — неполное обязательство, судить по нему нечего, и
/// ячейка ведёт себя как до обещания (`computed.abstinence-cell#7`).
AbstinenceCell abstinenceCellOf({
  required core.HabitDefinition definition,
  required int storedValue,
  required int day,
}) {
  final int? committedFrom = definition.committedFrom;
  if (committedFrom == null || day < committedFrom) {
    return AbstinenceCell.beforeCommitment;
  }
  if (storedValue == core.Entry.skip) return AbstinenceCell.skipped;
  return isAbstinenceLapseDay(definition, storedValue)
      ? AbstinenceCell.lapse
      : AbstinenceCell.clean;
}

class AbstinenceButtonView extends core.View {
  AbstinenceButtonView({
    required this.cell,
    required this.color,
    required this.theme,
    this.notes = '',
    this.textScaler = TextScaler.noScaling,
  });

  final AbstinenceCell cell;
  final core.Color color;
  final core.Theme theme;
  final String notes;

  /// Системный масштаб шрифта: глифы порта — sp, и этот тоже
  /// (`audit4.check-mark-cell-glyphs-no-longer#1`).
  final TextScaler textScaler;

  /// Глиф дня, или null — рисовать нечего.
  String? get glyph {
    switch (cell) {
      case AbstinenceCell.beforeCommitment:
        return null;
      case AbstinenceCell.clean:
        return core.FontAwesome.check;
      case AbstinenceCell.lapse:
        return core.FontAwesome.times;
      case AbstinenceCell.skipped:
        return core.FontAwesome.skipped;
    }
  }

  core.Color get glyphColor =>
      cell == AbstinenceCell.lapse ? theme.contrast60 : color;

  /// Полая галочка — то же начертание, каким порт рисует `YES_AUTO`.
  bool get isHollow => cell == AbstinenceCell.clean;

  double get fontSize =>
      textScaler.scale(isHollow ? yesAutoTextSize : smallTextSize);

  @override
  void draw(core.Canvas canvas) {
    final String? label = glyph;
    if (label == null) return;
    canvas.setFont(core.Font.fontAwesome);
    canvas.setFontSize(fontSize);
    canvas.setColor(glyphColor);

    final double em = canvas.measureText('m');
    final double x = canvas.getWidth() / 2.0;
    final double y = canvas.getHeight() / 2.0;

    if (isHollow) {
      // `paint.style = STROKE` порта, поверх — тот же глиф цветом карточки.
      canvas.setStrokeWidth(yesAutoStrokeWidth);
      if (canvas is TextOutlineCanvas) {
        (canvas as TextOutlineCanvas).drawTextOutline(label, x, y);
      } else {
        canvas.drawText(label, x, y);
      }
      canvas.setColor(theme.cardBackgroundColor);
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    } else {
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    }

    drawNotesIndicator(canvas, color: color, size: em, notes: notes);
  }
}
```

4. Прогнать тест — зелено.

5. Мутации (каждая правится обратной текстовой заменой, не `git checkout`):

| Мутация | Падает |
|---|---|
| `AbstinenceCell.clean` → `return core.FontAwesome.times;` в `glyph` | `#1` |
| `bool get isHollow => false;` | `#1` |
| тело `isAbstinenceLapseDay` → `storedValue > core.Entry.skip` (прежний `isLapseValue`) | `#2`: при допуске 30 величина 1 станет срывом, а обещание она держит; и «судья тот же, что у оценки» разойдётся на четырёх величинах из шести |
| `core.isAbstinenceLapse(definition, storedValue / 1000.0)` → `(definition, storedValue)` | `#2`: 29000 при допуске 30 станет срывом |
| убрать отсев `core.Entry.yesAuto` / `core.Entry.yesManual` | `#4` (yesAuto=1 даст 0.001 и станет срывом при допуске 0) |
| `committedFrom == null \|\| day < committedFrom` → `day < committedFrom - 1` | `#3` |
| убрать ветку `storedValue == core.Entry.skip` | `#4` |

6. Коммит: `abstinence: рисунок ячейки списка`.

---

### Task 34: панель рисует и маршрутизирует тап (4-ui-list.3)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/list/entry_panel.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/list/habit_card.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/list/abstinence_panel_test.dart`

**Interfaces:** Consumes — Task 4-ui-list.2, `core.HabitDefinition`. Produces —
`typedef EntryLapseCallback = Future<bool> Function(core.LocalDate date, bool lapsed);`,
поля `EntryPanel.abstinenceDefinition` (`core.HabitDefinition?`),
`EntryPanel.onLapse` (`EntryLapseCallback?`) и такие же два поля у `HabitCard`.

1. Тест первым. `app/test/ui/habits/list/abstinence_panel_test.dart`:

```dart
/// Панель дней привычки-воздержания: что рисуется и куда уходит жест.
///
/// Здесь только панель — без базы и без экрана. Что тап действительно пишет
/// срыв, проверяет `abstinence_cell_test.dart`.
library;

// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final core.Theme theme = core.LightTheme();

  late core.Preferences preferences;
  final List<({core.LocalDate date, bool lapsed})> lapses =
      <({core.LocalDate date, bool lapsed})>[];
  final List<core.LocalDate> edits = <core.LocalDate>[];

  /// Ответ двери записи: `true` — «записал», `false` — «ничего не записано».
  /// В этих двух случаях панель обязана вести себя по-разному.
  late bool writeSucceeds;

  setUp(() {
    core.setToday(core.LocalDate.ymd(2020, 1, 15));
    preferences = core.Preferences(core.MemoryStorage());
    lapses.clear();
    edits.clear();
    writeSucceeds = true;
  });

  tearDown(core.resetToday);

  /// Обязательство с допуском — то же, чем кормит панель список.
  ///
  /// Панели едет определение целиком, а не один день обещания: срывом день
  /// называет `isAbstinenceLapse(definition, величина)`, и допуск он берёт
  /// отсюда.
  core.HabitDefinition commitment({
    required int from,
    double allowance = 0.0,
  }) =>
      core.HabitDefinition(
        kind: core.ComputedKind.abstinence,
        committedFrom: from,
        payload: core.abstinencePayload(allowance: allowance),
      );

  Widget panel({
    required List<int> values,
    required core.HabitDefinition definition,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: EntryPanel(
            values: values,
            color: theme.colorOf(const core.PaletteColor(7)),
            theme: theme,
            preferences: preferences,
            isNumerical: true,
            abstinenceDefinition: definition,
            onLapse: (core.LocalDate date, bool lapsed) async {
              lapses.add((date: date, lapsed: lapsed));
              return writeSucceeds;
            },
            onEdit: edits.add,
          ),
        ),
      );

  AbstinenceButtonView viewAt(WidgetTester tester, core.LocalDate date) =>
      tester.widget<EntryButton>(find.byKey(EntryPanel.buttonKey(date))).view
          as AbstinenceButtonView;

  testWidgets('computed.abstinence-cell#1 воздержание не рисует числовую '
      'панель', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#1 — числовая ячейка написала бы «0»');
  });

  testWidgets('computed.abstinence-cell#5 тап сообщает о срыве, повторный — '
      'об отмене', (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses.single.lapsed, isTrue, reason: 'computed.abstinence-cell#5');
    expect(lapses.single.date, today, reason: 'computed.abstinence-cell#5');
    // Оптимистичная перерисовка: ячейка обязана показать крест до того, как
    // придут пересчитанные значения — иначе тап выглядит как ничего.
    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#5');

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses.last.lapsed, isFalse, reason: 'computed.abstinence-cell#5');
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5');
  });

  testWidgets('computed.abstinence-cell#3 день до обязательства не нажимается',
      (tester) async {
    final core.LocalDate today = core.getToday();
    // Обещание дано вчера: позавчерашняя ячейка вне обязательства.
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown, core.Entry.unknown, core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 1),
    ));

    final core.LocalDate before = today.minus(2);
    expect(viewAt(tester, before).cell, AbstinenceCell.beforeCommitment,
        reason: 'computed.abstinence-cell#3');

    await tester.tap(find.byKey(EntryPanel.buttonKey(before)));
    await tester.pump();

    expect(lapses, isEmpty, reason: 'computed.abstinence-cell#3');
    expect(edits, isEmpty, reason: 'computed.abstinence-cell#3');
  });

  testWidgets('computed.abstinence-cell#4 пропуск тапом в срыв не переводится',
      (tester) async {
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.skip],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pump();

    expect(lapses, isEmpty,
        reason: 'computed.abstinence-cell#4 — DayWriter всё равно не перепишет '
            'пропуск, и ячейка не должна врать, что перепишет');
    expect(viewAt(tester, today).cell, AbstinenceCell.skipped,
        reason: 'computed.abstinence-cell#4');
  });

  testWidgets('computed.abstinence-cell#7 без дня обязательства панель '
      'остаётся числовой', (tester) async {
    final core.LocalDate today = core.getToday();
    // Обе стороны в одном тесте. Проверка одного лишь `isNot(...)` зелена и
    // тогда, когда блока воздержания в `_buildButton` нет вовсе: она не
    // отличает «признак не сработал» от «кода нет».
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#7 — с признаком ячейка воздержания '
            'есть');

    // Тот же виджет, но признака нет: панель обязана вернуться к числу.
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: EntryPanel(
          values: <int>[core.Entry.unknown],
          color: theme.colorOf(const core.PaletteColor(7)),
          theme: theme,
          preferences: preferences,
          isNumerical: true,
          onEdit: edits.add,
        ),
      ),
    ));

    expect(
        tester
            .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(today)))
            .view,
        isNot(isA<AbstinenceButtonView>()),
        reason: 'computed.abstinence-cell#7');
  });

  testWidgets('computed.abstinence-cell#5 не записанный срыв ячейку не '
      'перекрашивает', (tester) async {
    // Оптимистичная краска есть обещание, а не факт. Дверь записи отвечает,
    // записала ли она что-нибудь; ответ «нет» — это и передумавший человек, и
    // отказ охраны, и в обоих случаях крест на ячейке был бы враньём до
    // ближайшей перерисовки списка, которой в этом случае не будет.
    final core.LocalDate today = core.getToday();
    writeSucceeds = false;
    await tester.pumpWidget(panel(
      values: <int>[core.Entry.unknown],
      definition: commitment(from: today.daysSince2000 - 30),
    ));

    await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
    await tester.pumpAndSettle();

    expect(lapses.single.lapsed, isTrue,
        reason: 'computed.abstinence-cell#5 — спросили дверь');
    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5 — и вернулись к галочке, потому '
            'что дверь ничего не записала');
  });

  testWidgets('computed.abstinence-cell#2 панель судит допуском, а не «есть '
      'запись»', (tester) async {
    // Двадцать минут при допуске тридцать: запись в дне есть, срыва нет.
    // Прежний `stored > Entry.skip` нарисовал бы здесь крест, а счётчик дней
    // без срыва при этом не сбросился бы — интерфейс спорил бы сам с собой.
    final core.LocalDate today = core.getToday();
    await tester.pumpWidget(panel(
      values: <int>[20000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более 30» обещание держит');

    await tester.pumpWidget(panel(
      values: <int>[31000],
      definition: commitment(
        from: today.daysSince2000 - 30,
        allowance: 30.0,
      ),
    ));

    expect(viewAt(tester, today).cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });
}
```

2. Запустить — падает на неизвестных именованных аргументах
   `abstinenceDefinition` и `onLapse` (`No named parameter with the name`).

3. Правки в `app/lib/ui/habits/list/entry_panel.dart`. Рядом с
   `typedef EntryEditCallback`:

```dart
/// Тап по ячейке привычки-воздержания. [lapsed] — состояние, в которое день
/// переходит: true — «в этот день я сорвался», false — снять срыв.
///
/// Отдельно от [EntryToggleCallback], а не «ещё одно значение» в нём: тот
/// уходит в `CreateRepetitionCommand`, а человек вычисляемой привычке значения
/// дня не пишет (`computed.write-paths#3`). Срыв — факт журнала, значение дня
/// из него считает приложение.
///
/// Отвечает, записала ли дверь хоть что-нибудь. Панель красит ячейку до
/// ответа — иначе тап выглядит как ничего, — и ответ «нет» обязана уметь
/// отменить: дверь может ничего не записать (человек закрыл ввод величины,
/// охрана отказала), а перерисовки списка в этом случае не будет, и крест
/// остался бы висеть враньём.
typedef EntryLapseCallback = Future<bool> Function(
    core.LocalDate date, bool lapsed);
```

В конструктор `EntryPanel` добавить `this.abstinenceDefinition,` и
`this.onLapse,`, а к полям:

```dart
  /// Определение привычки-воздержания, или null для любой другой привычки.
  ///
  /// Оно же и признак вида: воздержание — числовая привычка, и по [isNumerical]
  /// её от «прочитано страниц» не отличить. Признаком считается вид
  /// `abstinence` **с непустым** `committedFrom`; неполное определение
  /// признаком не считается — судить день как чистый или сорванный тогда не от
  /// чего, — и такая привычка остаётся числовой
  /// (`computed.abstinence-cell#7`). Считает признак поставщик,
  /// `HabitListModel.abstinenceDefinitionOf`; панель получает уже готовый
  /// ответ.
  ///
  /// Едет определение целиком, а не один день обещания, потому что срывом день
  /// называет `isAbstinenceLapse(definition, величина)` — тот же судья, что и
  /// у оценки, — и допуск он берёт отсюда.
  final core.HabitDefinition? abstinenceDefinition;

  /// Куда уходит тап по ячейке воздержания.
  final EntryLapseCallback? onLapse;
```

В `_EntryPanelState` рядом с `_optimisticValues`:

```dart
  /// То же, что [_optimisticValues], для ячейки воздержания: тап обязан
  /// перекрасить ячейку до того, как пересчёт вернётся через кэш списка.
  final Map<int, bool> _optimisticLapses = <int, bool>{};
```

и в `didUpdateWidget`, следующей строкой за `_optimisticValues.clear();`:

```dart
    _optimisticLapses.clear();
```

В `_buildButton`, **перед** `if (widget.isNumerical) {`:

```dart
    // Воздержание проверяется раньше числа: оно числовое, и обратный порядок
    // отдал бы его числовой панели.
    final core.HabitDefinition? definition = widget.abstinenceDefinition;
    if (definition != null) {
      final int stored = offset < widget.values.length
          ? widget.values[offset]
          : core.Entry.unknown;
      final AbstinenceCell stated = abstinenceCellOf(
        definition: definition,
        storedValue: stored,
        day: date.daysSince2000,
      );
      final bool? optimistic = _optimisticLapses[date.daysSince2000];
      final AbstinenceCell cell = optimistic == null ||
              stated == AbstinenceCell.beforeCommitment ||
              stated == AbstinenceCell.skipped
          ? stated
          : (optimistic ? AbstinenceCell.lapse : AbstinenceCell.clean);

      // Нажимаются только те два состояния, которые тап умеет менять. День до
      // обещания менять нечему (`#3`), а пропуск — отметка человека, которую
      // `DayWriter` всё равно не перепишет (`#4`).
      final bool tappable =
          cell == AbstinenceCell.clean || cell == AbstinenceCell.lapse;

      Future<void> lapse() async {
        final bool next = cell != AbstinenceCell.lapse;
        reportPress();
        setState(() => _optimisticLapses[date.daysSince2000] = next);
        performToggleFeedback();
        // Красим до ответа и снимаем краску, если ответ «ничего не записано»:
        // перерисовки списка в этом случае не будет, и оставленный крест
        // соврал бы до следующего чужого повода перестроить строку.
        final bool written = await widget.onLapse?.call(date, next) ?? false;
        if (!written && mounted) {
          setState(() => _optimisticLapses.remove(date.daysSince2000));
        }
      }

      // Долгое нажатие остаётся тем же жестом, что и у числовой ячейки, и
      // упирается в тот же запрет: числа человек здесь не вводит
      // (`computed.abstinence-cell#6`).
      void editFromLongPress() {
        reportPress();
        widget.onEdit?.call(date);
        performLongPressFeedback();
      }

      return EntryButton(
        key: key,
        size: size,
        view: AbstinenceButtonView(
          cell: cell,
          color: widget.color,
          theme: widget.theme,
          notes: note,
          textScaler: MediaQuery.textScalerOf(context),
        ),
        onTap: tappable ? () => unawaited(lapse()) : null,
        onLongPress: tappable ? editFromLongPress : null,
      );
    }
```

и импорты вверху файла:

```dart
import 'dart:async' show unawaited;

import '../abstinence/abstinence_button_view.dart';
```

4. В `app/lib/ui/habits/list/habit_card.dart` добавить в конструктор
   `this.abstinenceDefinition,` и `this.onLapse,`, к полям:

```dart
  /// Определение, если это привычка-воздержание; иначе null. Карточка его не
  /// добывает — [HabitListModel.abstinenceDefinitionOf] её кормит.
  final core.HabitDefinition? abstinenceDefinition;

  /// Ячейка воздержания сообщила о срыве.
  final EntryLapseCallback? onLapse;
```

а в `_buildPanel`, в конструктор `EntryPanel`, рядом с `onEdit:`:

```dart
      abstinenceDefinition: widget.abstinenceDefinition,
      onLapse: widget.onLapse,
```

5. Прогнать `flutter test test/ui/habits/list/abstinence_panel_test.dart` плюс
   уже существующие `habit_card_test.dart`, `entry_panel_test.dart` (если есть)
   и `computed_list_edit_test.dart` — все зелёные.

6. Мутации:

| Мутация | Падает |
|---|---|
| перенести блок воздержания **после** `if (widget.isNumerical)` | `#1` |
| `onTap: tappable ? () => unawaited(lapse()) : null` → `onTap: () => unawaited(lapse())` | `#3`, `#4` |
| убрать `setState(() => _optimisticLapses[...] = next);` | `#5` (ячейка не перекрашивается) |
| `final bool next = cell != AbstinenceCell.lapse;` → `= true` | `#5` (второй тап не отменяет) |
| убрать `if (!written && mounted) { setState(...remove...); }` | «не записанный срыв ячейку не перекрашивает» |
| `abstinenceCellOf(definition: definition, …)` → судить прежним `stored > core.Entry.skip` | «панель судит допуском, а не «есть запись»» |
| убрать `_optimisticLapses.clear()` из `didUpdateWidget` | не ловится здесь — ловится в Task 4-ui-list.4 |

7. Коммит: `abstinence: панель дней рисует воздержание и уводит тап в журнал`.

---

### Task 35: список пишет срыв (4-ui-list.4)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_gestures.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/state/habit_list_model.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/list/habit_list_screen.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/list/abstinence_cell_test.dart`

**Interfaces:** Consumes — `AppScope.abstinence.setLapse` (Задача 24; он же и
объявляет об изменении, изнутри `DayWriter`), `AppScope.lapses`,
`DefinitionRepository.forHabit`. Produces —
`bool setLapseDay(AppScope scope, {required core.Habit habit, required core.LocalDate date, required bool lapsed, int? amount})`,
`core.HabitDefinition? HabitListModel.abstinenceDefinitionOf(core.Habit habit)`.

1. Тест первым. `app/test/ui/habits/list/abstinence_cell_test.dart` — тот же
   каркас, что у соседнего `computed_list_edit_test.dart`:

```dart
/// Тап по ячейке воздержания на настоящем экране списка.
///
/// Запрет на ввод числа вычисляемой привычке уже стоит и проверен
/// `computed_list_edit_test.dart`. Здесь проверяется, что второй житель слоя
/// проходит мимо этого запрета не в обход его, а другой дверью: журнал срывов.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_cell');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// Воздержание: числовая привычка с целью «не больше нуля» и определением,
  /// у которого есть день обещания.
  Habit addAbstinence(AppScope scope, {required int committedFrom}) {
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
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Future<void> tapToday(WidgetTester tester) async {
    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
  }

  /// Срыв ли этот день — спрошено у того же судьи, что судит оценку.
  ///
  /// Не `значение > Entry.skip`: при допуске больше нуля запись в дне есть, а
  /// срыва нет, и «есть запись» ответило бы не на тот вопрос.
  bool lapsedOn(AppScope scope, Habit habit, LocalDate date) =>
      isAbstinenceLapseDay(scope.definitions.forHabit(habit.id!)!,
          habit.originalEntries.get(date).value);

  testWidgets('computed.abstinence-cell#5 тап записывает срыв, повторный '
      'снимает', (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);

    expect(scope.lapses.lastDay(habit.id!), today,
        reason: 'computed.abstinence-cell#5');
    expect(lapsedOn(scope, habit, getToday()), isTrue,
        reason: 'computed.abstinence-cell#5 — день пересчитан, а не только '
            'записан в журнал');

    await tapToday(tester);

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-cell#5');
    expect(lapsedOn(scope, habit, getToday()), isFalse,
        reason: 'computed.abstinence-cell#5 — отмена возвращает день в тишину');
  });

  testWidgets('computed.abstinence-cell#6 числового окна нет ни на тапе, ни '
      'на долгом нажатии', (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);
    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6');

    await tester.longPress(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6 — тот же запрет, что у сна без '
            'ночи (computed.write-paths#3)');
  });

  testWidgets('computed.abstinence-cell#5 список перерисовывается сам',
      (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);
    // Кэш списка обязан отдать пересчитанное значение: оптимистичная краска
    // стирается в didUpdateWidget, и если хук инвалидации не дёрнут, ячейка
    // вернётся к чистой.
    await tester.pumpAndSettle();

    final AbstinenceButtonView view = tester
        .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
        .view as AbstinenceButtonView;
    expect(view.cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#5 — onComputedDataChanged');
  });
}
```

2. Запустить — падает: у `AppScope` нет `lapses`/`abstinence` (если секции ядра
   ещё нет) либо ячейка рисуется числовой (`type 'NumberButtonView' is not a
   subtype of type 'AbstinenceButtonView'`).

3. Создать `app/lib/ui/habits/abstinence/abstinence_gestures.dart`:

```dart
/// Единственная дверь, которой жест пишет срыв.
library;

import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../state/app_scope.dart';

/// Записывает или снимает срыв за [date]. Отвечает, записала ли.
///
/// Одна функция, а не вызов на каждом жесте: путей записи два — ячейка списка
/// и календарь на экране привычки, — и правило, размазанное по обоим, будет
/// донесено до одного.
///
/// [amount] — измеренная величина дня в единице привычки. `null` значит «одна
/// единица»: при допуске ноль тап и есть весь факт, спрашивать нечего
/// (`computed.lapses#2`). Когда допуск больше нуля, величину спрашивают —
/// но спрашивают выше, в [toggleLapseDay]; эта дверь только пишет.
///
/// Об изменении **не объявляет**: это делает `DayWriter`, которым собран
/// `AbstinenceSync` в `AppScope.open` (Задача 24). Второй вызов
/// `onComputedDataChanged` отсюда дал бы два объявления на один тап — и, что
/// хуже, снял бы вопрос «а пересчитана ли привычка до объявления»
/// (`computed.freshness#2`, `#4`).
bool setLapseDay(
  AppScope scope, {
  required core.Habit habit,
  required core.LocalDate date,
  required bool lapsed,
  int? amount,
}) {
  final int? id = habit.id;
  if (id == null) return false;
  scope.abstinence.setLapse(habit, date, lapsed, amount: amount);
  return true;
}
```

4. В `app/lib/state/habit_list_model.dart` — признак для карточки:

```dart
  /// Определение привычки-воздержания, или null для любой другой.
  ///
  /// Читается из базы, но не на каждый кадр: строка списка перестраивается на
  /// каждой прокрутке, а определение меняется только вместе с моделью — и
  /// [notifyListeners] и есть тот момент, когда старый ответ перестаёт быть
  /// верным.
  ///
  /// `kind` спрашивается наравне с днём: у сна `committed_from` есть null, и
  /// «непустой день» без проверки вида был бы признаком, который однажды
  /// поймает не того. Признак считается здесь, один раз, и ниже едет уже
  /// готовый ответ — определение целиком, потому что срывом день называет
  /// `isAbstinenceLapse(definition, величина)`, и допуск он берёт оттуда.
  HabitDefinition? abstinenceDefinitionOf(Habit habit) {
    final int? id = habit.id;
    if (id == null) return null;
    return _abstinenceDefinitions.putIfAbsent(id, () {
      final HabitDefinition? definition = scope.definitions.forHabit(id);
      if (definition == null) return null;
      if (definition.kind != ComputedKind.abstinence) return null;
      if (definition.committedFrom == null) return null;
      return definition;
    });
  }

  final Map<int, HabitDefinition?> _abstinenceDefinitions =
      <int, HabitDefinition?>{};

  @override
  void notifyListeners() {
    _abstinenceDefinitions.clear();
    super.notifyListeners();
  }
```

5. В `app/lib/ui/habits/list/habit_list_screen.dart`, в `_buildCard`, рядом с
   `onEdit:` (сам блок `onEdit` не трогается — запрет остаётся дословно):

```dart
      abstinenceDefinition: model.abstinenceDefinitionOf(habit),
      onLapse: (core.LocalDate date, bool lapsed) async => setLapseDay(
        _model.scope,
        habit: habit,
        date: date,
        lapsed: lapsed,
      ),
```

и импорт `import '../abstinence/abstinence_gestures.dart';`.

6. Прогнать новый тест и оба уже существующих файла запрета:

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test \
  test/ui/habits/list/abstinence_cell_test.dart \
  test/ui/habits/list/computed_list_edit_test.dart \
  test/ui/sleep/calendar_editor_guard_test.dart
```

`computed_list_edit_test.dart` обязан остаться зелёным **дословно**: его
определение воздержания сохранено без `committedFrom`, ячейка остаётся
числовой, и тап по-прежнему упирается в отказ.

7. Мутации:

| Мутация | Падает |
|---|---|
| собрать `AbstinenceSync` в `AppScope.open` с `const DayWriter()` вместо объявляющего | «список перерисовывается сам» |
| убрать `scope.abstinence.setLapse(...)` | `#5` |
| `if (definition.kind != ComputedKind.abstinence) return null;` убрать | `computed_list_edit_test` (сон получит ячейку воздержания) |
| `if (definition.committedFrom == null) return null;` убрать | `computed_list_edit_test` и `calendar_editor_guard_test`: их определение сохранено без дня обещания и обязано остаться числовой привычкой (`computed.abstinence-cell#7`) |
| `notifyListeners` без `_abstinenceDefinitions.clear()` | `#5` для привычки, чей допуск или день обещания изменили на ходу — не ловится этим набором; оставить как известный предел мемо |
| `onLapse` не передан в `HabitCard` | `#5` |

8. Коммит: `abstinence: тап по ячейке списка пишет срыв`.

---

### Task 36: счётчик «дней без срыва» на экране привычки (4-ui-list.5)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/computed/computed_card.dart`
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_counter.dart`
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_section.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart`

**Interfaces:** Consumes — `AppScope.lapses.lastDay`, `setLapseDay`,
`isAbstinenceLapseDay` (Задача 33), ядровая
`daysWithoutLapse(core.Habit, {core.LocalDate? asOf})` (Задача 16), L10n из
Задачи 32. Produces — `class AbstinenceCounterCard` с
`static const Key cardKey` и `static const Key todayButtonKey`,
`List<Widget> buildAbstinenceSection(BuildContext, {required AppScope scope, required core.Habit habit, required core.HabitDefinition definition, required core.Theme theme, required VoidCallback onChanged})`.

Определение приезжает целиком, а не одним днём обязательства: «сорвался ли я
сегодня» — вопрос к тому же судье, что судит оценку
(`isAbstinenceLapse(definition, величина)`), и надпись на кнопке обязана
совпадать с крестом в ячейке и с числом на счётчике. День обязательства
берётся из него же — `definition.committedFrom!`, непустой по построению
признака.

Место в колонке: счётчик идёт **первым**, выше портированных карточек. У сна
портированная четвёрка стоит выше его блоков, потому что те блоки — механика.
Здесь наоборот: «сорок дней без срыва» это и есть привычка, ради этой строки
экран и открывают.

1. Тест первым. `app/test/ui/habits/show/abstinence_screen_test.dart`:

```dart
/// Экран привычки-воздержания.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_counter.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_section.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_screen');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Habit addAbstinence({required int committedFrom}) {
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
    habit.recompute();
    return habit;
  }

  Widget wrap(Habit habit) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  testWidgets('computed.abstinence-screen#1 счётчик считается от дня '
      'обязательства', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('40'), findsOneWidget,
        reason: 'computed.abstinence-screen#1 — сорок чистых дней до первого '
            'срыва существуют, и считаются они от обещания, а не от первой '
            'записи');
    expect(find.text('дней без срыва'), findsOneWidget,
        reason: 'computed.abstinence-screen#1 — по-русски, множественное '
            'число от 40');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.abstinence-screen#1 — пока срывов не было, под '
            'числом стоит день обещания');
  });

  testWidgets('computed.abstinence-screen#2 после срыва счётчик считается от '
      'него', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    scope.abstinence.setLapse(habit, LocalDate(today - 3), true);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    // Срыв был три дня назад: серия началась два дня назад, и прошедшего
    // времени в ней два дня (`computed.streak#4`).
    expect(find.text('2'), findsOneWidget,
        reason: 'computed.abstinence-screen#2');
    expect(find.text('дня без срыва'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — «2 дня», не «2 дней»');
    expect(find.textContaining('Последний срыв:'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — подпись меняется вместе с '
            'числом');
  });

  testWidgets('computed.abstinence-screen#3 счётчик стоит выше портированных '
      'карточек', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    final double counter =
        tester.getTopLeft(find.byKey(AbstinenceCounterCard.cardKey)).dy;
    final double subtitle = tester
        .getTopLeft(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.subtitle)))
        .dy;
    expect(counter, lessThan(subtitle),
        reason: 'computed.abstinence-screen#3');
  });

  testWidgets('computed.abstinence-screen#4 цель скрыта, кольцо показано',
      (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.target)),
        findsNothing,
        reason: 'computed.abstinence-screen#4 — неделя без срывов это не '
            '«0% в неделю»');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.overview)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4');
  });

  testWidgets('computed.abstinence-screen#5 кнопка пишет и снимает срыв за '
      'сегодня', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();
    expect(find.text('Сегодня сорвался'), findsOneWidget,
        reason: 'computed.abstinence-screen#5');

    await tester.tap(find.byKey(AbstinenceCounterCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), today,
        reason: 'computed.abstinence-screen#5');
    expect(find.text('0'), findsWidgets,
        reason: 'computed.abstinence-screen#2 — срыв сегодня обнуляет счётчик');
    expect(find.text('Отменить за сегодня'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — надпись идёт за днём');

    await tester.tap(find.byKey(AbstinenceCounterCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#5');
  });

  testWidgets('Bar и Frequency остаются на экране намеренно', (tester) async {
    // Спецификация выносит решение по ним отдельно, и оно принято: отложить.
    // Тест держит это как решение, а не как забывчивость, — когда карточки
    // решат прятать, падёт именно он (DEVIATIONS.md, «computed: воздержание не
    // трогает виджеты, Bar и Frequency»).
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.bar)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4 — скрывается только карточка '
            'цели; Bar и Frequency оставлены, решение отложено спецификацией');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.frequency)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4');
  });
}
```

2. Запустить — падает на отсутствующем файле `abstinence_counter.dart`.

3. Создать `app/lib/ui/habits/computed/computed_card.dart`:

```dart
/// Оправа блока вычисляемой привычки — та же, что у карточек ниже.
///
/// Копия `SleepCard`, а не его переиспользование: у сна оправа названа по виду,
/// и импортировать «сон» в воздержание — врать про то, что это. Когда сон
/// переедет на слой 2 (шаг 4 в «Порядке работы»), `SleepCard` схлопывается
/// сюда; до тех пор две копии в тридцать строк дешевле, чем один общий файл с
/// неверным именем.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// Та же округлённая конверсия, что у `FlutterCanvas.setColor`.
Color toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round(),
      (color.red * 255).round(),
      (color.green * 255).round(),
      (color.blue * 255).round(),
    );

class ComputedCard extends StatelessWidget {
  const ComputedCard({
    required this.theme,
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final core.Theme theme;
  final String title;
  final Widget child;
  final Widget? trailing;

  static const EdgeInsets margin = EdgeInsets.fromLTRB(3, 0, 3, 1);
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 16, 16, 16);
  static const double elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        elevation: elevation,
        color: toFlutterColor(theme.cardBackgroundColor),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w500,
                        color: toFlutterColor(theme.mediumContrastTextColor),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
```

4. Создать `app/lib/ui/habits/abstinence/abstinence_counter.dart`:

```dart
/// «Дней без срыва» — число и карточка, которая его показывает.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../computed/computed_card.dart';

// Своей `daysWithoutLapse` здесь нет и быть не должно. Она есть в ядре
// (`computed/days_without_lapse.dart`, Задача 16), считает по текущей серии, а
// не по последнему срыву, и потому переживает «срыв в будущем» и не требует
// второго запроса к журналу. Две функции с одним именем — в ядре и здесь —
// давали на одних данных разные числа, а этот файл и бочка ядра импортируются
// в один и тот же тест: `Error: 'daysWithoutLapse' is imported from both`.
// Отсюда наружу идёт только карточка.

class AbstinenceCounterCard extends StatelessWidget {
  const AbstinenceCounterCard({
    required this.theme,
    required this.days,
    required this.subtitle,
    required this.lapsedToday,
    required this.onToggleToday,
    super.key = cardKey,
  });

  final core.Theme theme;
  final int days;

  /// Строка под числом: «С 3 марта 2026» или «Последний срыв: 12 августа».
  final String subtitle;

  /// Сегодняшний день уже отмечен срывом.
  final bool lapsedToday;

  final VoidCallback onToggleToday;

  static const Key cardKey = Key('abstinence.counter');
  static const Key todayButtonKey = Key('abstinence.today');

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    return ComputedCard(
      theme: theme,
      title: l10n.abstinenceTitle,
      trailing: TextButton(
        key: todayButtonKey,
        onPressed: onToggleToday,
        child: Text(
          lapsedToday ? l10n.abstinenceUndoToday : l10n.abstinenceLapseToday,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$days',
                style: TextStyle(
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: toFlutterColor(theme.highContrastTextColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.abstinenceCleanDaysLabel(days),
                style: TextStyle(
                  fontSize: 15,
                  color: toFlutterColor(theme.mediumContrastTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
        ],
      ),
    );
  }
}
```

5. Создать `app/lib/ui/habits/abstinence/abstinence_section.dart`:

```dart
/// Блоки, которые получает привычка-воздержание и не получает никакая другая.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../list/list_header.dart' show IntlLocalDateFormatter;
import 'abstinence_button_view.dart' show isAbstinenceLapseDay;
import 'abstinence_counter.dart';
import 'abstinence_gestures.dart';

/// Функция, а не виджет: она отдаёт те же карточки, что и портированная
/// колонка, и обёртка вокруг них поставила бы шов посреди одного экрана.
/// Ровно как `buildSleepSection`.
List<Widget> buildAbstinenceSection(
  BuildContext context, {
  required AppScope scope,
  required core.Habit habit,
  required core.HabitDefinition definition,
  required core.Theme theme,
  required VoidCallback onChanged,
}) {
  final int id = habit.id!;
  final int committedFrom = definition.committedFrom!;
  final core.LocalDate today = core.getToday();
  // Из журнала берётся только подпись: какое число показать, знает ядро.
  final int? lastLapse = scope.lapses.lastDay(id);
  // Тот же судья, что у ячейки и у оценки. «Есть запись в дне» ответило бы не
  // на тот вопрос: при допуске 30 двадцать минут записаны, а срыва нет, и
  // кнопка предложила бы «Отменить за сегодня» там, где счётчик показывает
  // сорок дней без срыва.
  final bool lapsedToday =
      isAbstinenceLapseDay(definition, habit.originalEntries.get(today).value);
  final IntlLocalDateFormatter formatter = IntlLocalDateFormatter.of(context);
  final L10n l10n = L10n.of(context);

  return <Widget>[
    AbstinenceCounterCard(
      theme: theme,
      days: core.daysWithoutLapse(habit),
      subtitle: lastLapse == null || lastLapse < committedFrom
          ? l10n.abstinenceSince(
              formatter.longFormat(core.LocalDate(committedFrom)))
          : l10n.abstinenceLastLapse(
              formatter.longFormat(core.LocalDate(lastLapse))),
      lapsedToday: lapsedToday,
      onToggleToday: () {
        setLapseDay(scope, habit: habit, date: today, lapsed: !lapsedToday);
        onChanged();
      },
    ),
  ];
}
```

6. Правки в `app/lib/ui/habits/show/show_habit_screen.dart`.

   а) Механический переименовыв: перерисовка перестала быть сонной.

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && \
  sed -i '' 's/_repaintSleep/_repaintComputed/g' lib/ui/habits/show/show_habit_screen.dart
```

   б) Новый геттер рядом с `_isComputed`:

```dart
  /// Определение, если это привычка-воздержание; иначе null.
  ///
  /// Признаком служит вид `abstinence` **с непустым** днём обещания, а не один
  /// вид: определение без дня неполно — судить день как чистый или сорванный
  /// не от чего, — и такая привычка ведёт себя как любая другая вычисляемая
  /// (`computed.abstinence-cell#7`).
  ///
  /// Отдаётся определение целиком, а не день: срывом день называет
  /// `isAbstinenceLapse(definition, величина)`, и допуск он берёт отсюда. Тот
  /// же ответ, что кормит ячейку списка, — и считается он тем же способом.
  core.HabitDefinition? get _abstinenceDefinition {
    final int? id = widget.habit.id;
    if (id == null) return null;
    final core.HabitDefinition? definition =
        widget.scope.definitions.forHabit(id);
    if (definition == null) return null;
    if (definition.kind != core.ComputedKind.abstinence) return null;
    if (definition.committedFrom == null) return null;
    return definition;
  }
```

   в) `_buildColumn` — счётчик первым:

```dart
  List<Widget> _buildColumn(BuildContext context, ShowHabitModel model) {
    // Воздержание кладёт свою карточку НАД портированными, а сон — под
    // четвёркой: у сна собственные блоки есть механика, а «сорок дней без
    // срыва» есть сама привычка (`computed.abstinence-screen#3`).
    final List<Widget> abstinence = _buildAbstinenceCards(context, model);
    if (abstinence.isNotEmpty) {
      return <Widget>[...abstinence, ..._buildCards(context, model)];
    }
    final List<Widget> sleep = _buildSleepCards(context, model);
    if (sleep.isEmpty) return _buildCards(context, model);
    return <Widget>[
      ..._buildCards(context, model, only: _sleepLeadingCards),
      ...sleep,
      ..._buildCards(context, model, except: _sleepLeadingCards),
    ];
  }

  /// Пусто для всякой привычки без дня обязательства — тот же признак, каким
  /// решает ячейка списка.
  List<Widget> _buildAbstinenceCards(
      BuildContext context, ShowHabitModel model) {
    final core.HabitDefinition? definition = _abstinenceDefinition;
    if (definition == null) return const <Widget>[];
    return buildAbstinenceSection(
      context,
      scope: widget.scope,
      habit: widget.habit,
      definition: definition,
      theme: model.state.theme,
      onChanged: _repaintComputed,
    );
  }
```

   г) Замена цели на кольцо — обобщается со сна на любую вычисляемую привычку
   этой пары. В `_buildCards`:

```dart
    // Карточка цели складывает значения за неделю и месяц. Для доли ночи это
    // бессмыслица, и для срывов тоже: неделя без срывов — не «0% в неделю».
    // Обе получают взамен кольцо Overview
    // (`show-habit.card-order-and-visibility#2`,
    // `computed.abstinence-screen#4`).
    final bool swapsTargetForOverview = (habitId != null &&
            widget.scope.sleepRepository.goalFor(habitId) != null) ||
        _abstinenceDefinition != null;
```

и всюду в этом методе и в `_isVisible` переименовать `isSleep` в
`swapsTargetForOverview`. Мест ровно **четыре**, и на диске они такие
(`app/lib/ui/habits/show/show_habit_screen.dart`):

| Строка | Что там |
|---|---|
| `:900` | объявление в `_buildCards`: `final bool isSleep = habitId != null &&` |
| `:907` | аргумент в вызове: `if (!_isVisible(model, card, isSleep: isSleep)) continue;` |
| `:927` | параметр `_isVisible`: `required bool isSleep,` |
| `:929` | тело `_isVisible`: `if (!isSleep) return model.isVisible(card);` |

`grep -n "isSleep" app/lib/ui/habits/show/show_habit_screen.dart` после правки
обязан не найти ничего: четвёртое место — тело — забывается легче остальных
трёх, и забытое даёт привычке-воздержанию карточку цели обратно.

Скрывается **только** карточка цели. Bar и Frequency остаются и продолжают
складывать значения дней как проценты — спецификация выносит решение по ним
отдельно, и оно принято: отложить, а не сделать наполовину. Дописать это
комментарием там же, где стоит `swapsTargetForOverview`:

```dart
    // Прячется только цель. Bar и Frequency остаются намеренно: спецификация
    // требует решать по ним отдельно, решение отложено и записано в
    // DEVIATIONS.md («computed: воздержание не трогает виджеты, Bar и
    // Frequency»). Тест «Bar и Frequency остаются на экране намеренно»
    // держит это как решение, а не как забывчивость.
```

   д) Импорт `import '../abstinence/abstinence_section.dart';`.

7. Прогнать `flutter test test/ui/habits/show/` целиком: портированные тесты
   карточек обязаны остаться зелёными — для привычки без определения ни одна
   ветка не меняется.

8. Мутации:

| Мутация | Падает |
|---|---|
| `days: core.daysWithoutLapse(habit)` → `core.daysWithoutLapse(habit) + 1` | `#1`, `#2` |
| подпись всегда `abstinenceSince` (игнорировать `lastLapse`) | `#2` — «Последний срыв:» не найдено |
| счётчик после `_buildCards(...)` вместо перед | `#3` |
| спрятать Bar вместе с целью | «Bar и Frequency остаются на экране намеренно» |
| `swapsTargetForOverview` без ветки воздержания | `#4` |
| `lapsedToday` жёстко `false` | `#5` (надпись не меняется) |
| убрать `onChanged()` из `onToggleToday` | `#5` (счётчик остаётся прежним) |
| в `app_ru.arb` вернуть английские строки | `#1` (`дней без срыва` не найдено) |

9. Коммит: `abstinence: счётчик дней без срыва на экране привычки`.

---

### Task 37: величину спрашивают, когда допуск её требует (4-ui-list.9)

**Files:**
- Create: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_amount_dialog.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_gestures.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/list/habit_list_screen.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_section.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/abstinence/abstinence_allowance_test.dart` (create)

**Interfaces:**
- Потребляет: `abstinenceAllowanceOf` (Задача 2), `isAbstinenceLapseDay` и
  `abstinenceCellOf` (Задача 33), `setLapseDay` (Задача 35),
  `AbstinenceCounterCard` (Задача 36), портированный
  `showNumberDialog` (`app/lib/ui/common/dialogs/number_dialog.dart`),
  ядровая `daysWithoutLapse` (Задача 16).
- Даёт:

```dart
// app/lib/ui/habits/abstinence/abstinence_amount_dialog.dart
Future<int?> askLapseAmount(BuildContext context, {required core.HabitDefinition definition, required core.Preferences preferences, required core.Color color});

// app/lib/ui/habits/abstinence/abstinence_gestures.dart
Future<bool> toggleLapseDay(BuildContext context, AppScope scope, {required core.Habit habit, required core.HabitDefinition definition, required core.LocalDate date, required bool lapsed, required core.Theme theme});
```

- Даёт правило `computed.abstinence-cell#8`. Новых строк локализации — ни
  одной: диалог портированный и говорит своими.

**Зачем.** Допуск ноль — умолчание, и на нём тап есть весь факт: «закурил» не
имеет количества, спрашивать нечего, и лишний шаг на самом частом жесте был бы
не строгостью, а налогом. Но допуск бывает и не ноль: «не более 30 минут» — это
про число, и без числа оно не выражается. Молчаливый `amount = 1` при допуске
30 записал бы день, который обещание **держит**, и оставил бы приложение
спорить с самим собой: ячейка (после Задачи 33) нарисовала бы галочку, потому
что 1 ≤ 30, а человек только что сказал «я сорвался» и не увидел никакого
следа. Либо число спрашивают, либо жест врёт.

Дверь для этого заводится **своя**. Общая дверь ввода числа — `showNumberPopup`
на экране привычки и в списке — закрыта охраной вычисляемых привычек
(`computed.write-paths#3`), и она обязана остаться закрытой: человек не пишет
вычисляемой привычке значение дня. Здесь он пишет не значение дня, а **величину
в журнал**; значение дня из неё считает приложение. Виджет диалога берётся тот
же — портированный `NumberDialog`, — а вход другой.

- [ ] **Шаг 1: написать падающий тест**

Создать `app/test/ui/habits/abstinence/abstinence_allowance_test.dart`. Это и
есть тест на согласие троих: ячейка списка, кнопка карточки и счётчик дней без
срыва спрошены об одном и том же дне и обязаны ответить одно.

```dart
/// Допуск больше нуля: жест спрашивает величину, и трое отвечают одинаково.
///
/// «Не более 30 минут» без числа не выражается. Молчаливый `amount = 1` при
/// допуске 30 записал бы день, который обещание держит, а покрасил бы его как
/// срыв — и тогда ячейка говорила бы «сорвался», счётчик «сорок дней без
/// срыва», а балл не шелохнулся бы. Здесь эти трое спрошены об одном дне.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late Habit habit;

  /// «Не более [allowance] минут в день», обещание дано сорок дней назад.
  ///
  /// Допуск пишется в двух местах одним движением, потому что судьи два лица
  /// одного числа: `payload` читает интерфейс, `targetValue` — оценка
  /// (`computed.allowance#1`).
  void commit({required double allowance}) {
    habit.targetValue = allowance;
    scope.habitList.update(<Habit>[habit]);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: getToday().daysSince2000 - 40,
        payload: abstinencePayload(
          allowance: allowance,
          unit: allowance == 0.0
              ? abstinenceUnitCount
              : abstinenceUnitMinutes,
        ),
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
  }

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_allowance');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;

    habit = scope.modelFactory.buildHabit()
      ..name = 'Screen time'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 30
      ..unit = 'minutes';
    scope.habitList.add(habit);
    commit(allowance: 30.0);
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget list() => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Widget screen() => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  AbstinenceCell cellToday(WidgetTester tester) => (tester
          .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
          .view as AbstinenceButtonView)
      .cell;

  Future<void> tapToday(WidgetTester tester) async {
    await tester.pumpWidget(list());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, String amount) async {
    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8 — при допуске больше нуля тап '
            'спрашивает величину');
    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), amount);
    await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
    await tester.pumpAndSettle();
  }

  int get todayDay => getToday().daysSince2000;

  testWidgets('computed.abstinence-cell#8 двадцать минут при допуске тридцать '
      'обещание держат, и трое согласны', (tester) async {
    await tapToday(tester);
    await answer(tester, '20');

    // Журнал записал двадцать, а не «единицу»: величина есть факт дня.
    expect(scope.lapses.forDay(habit.id!, todayDay), 20,
        reason: 'computed.abstinence-cell#8');

    // Первый из троих — ячейка списка.
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более 30» обещание держит');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Второй — кнопка карточки.
    expect(find.text('Сегодня сорвался'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — предлагать «Отменить за '
            'сегодня» там, где срыва не было, значит спорить с ячейкой');
    // Третий — счётчик.
    expect(find.text('40'), findsOneWidget,
        reason: 'computed.streak#4 — двадцать минут серию не рвут');
  });

  testWidgets('computed.abstinence-cell#8 сорок пять минут — срыв, и трое '
      'согласны с этим', (tester) async {
    await tapToday(tester);
    await answer(tester, '45');

    expect(scope.lapses.forDay(habit.id!, todayDay), 45,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Отменить за сегодня'), findsOneWidget,
        reason: 'computed.abstinence-screen#5');
    expect(find.text('0'), findsWidgets,
        reason: 'computed.streak#5 — срыв сегодня обнуляет счётчик');
  });

  testWidgets('computed.abstinence-cell#8 вопрос без ответа фактом не '
      'становится', (tester) async {
    await tapToday(tester);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8');
    Navigator.of(tester.element(find.byType(NumberDialog))).pop();
    await tester.pumpAndSettle();

    expect(scope.lapses.forDay(habit.id!, todayDay), isNull,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5 — и оптимистичная краска снята: '
            'перерисовать список тут нечему, и крест остался бы висеть');
  });

  testWidgets('computed.abstinence-cell#8 ноль — это молчание, а не срыв',
      (tester) async {
    // Ноль удовлетворяет «не больше допуска» при любом допуске, то есть
    // означает «ничего не было». Молчание есть отсутствие строки
    // (`computed.lapses#1`, `#2`), поэтому ноль в ответе равен отказу.
    await tapToday(tester);
    await answer(tester, '0');

    expect(scope.lapses.forDay(habit.id!, todayDay), isNull,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#8');
  });

  testWidgets('computed.abstinence-cell#8 при допуске ноль вопроса нет',
      (tester) async {
    commit(allowance: 0.0);

    await tapToday(tester);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6 — общая дверь числа закрыта, и на '
            'умолчании лишнего шага нет');
    expect(scope.lapses.forDay(habit.id!, todayDay),
        LapseRepository.minimumAmount,
        reason: 'computed.abstinence-cell#8 — тап пишет одну единицу, как и '
            'было');
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });

  testWidgets('computed.abstinence-cell#8 снятие срыва величины не спрашивает',
      (tester) async {
    await tapToday(tester);
    await answer(tester, '45');

    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#8 — «этого не было» количества не '
            'имеет');
    expect(scope.lapses.forDay(habit.id!, todayDay), isNull,
        reason: 'computed.abstinence-cell#5');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app
flutter test test/ui/habits/abstinence/abstinence_allowance_test.dart
```
Ожидается FAIL на первом же тесте: `Expected: exactly one matching candidate
Actual: _TypeWidgetFinder:<Found 0 widgets with type NumberDialog>` — тап
сегодня молча пишет единицу и ничего не спрашивает.

- [ ] **Шаг 3: написать вопрос**

Создать `app/lib/ui/habits/abstinence/abstinence_amount_dialog.dart`:

```dart
/// «Сколько сегодня?» — величина срыва, когда допуск её требует.
library;

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../common/dialogs/number_dialog.dart';

/// Спрашивает величину дня и отдаёт её в целых единицах привычки, или null,
/// когда ответа не было.
///
/// Свой маршрут, а не общая дверь числа. `showNumberPopup` — и в списке, и на
/// экране привычки — закрыт охраной вычисляемых привычек
/// (`computed.write-paths#3`), и открывать его ради воздержания значило бы
/// снять запрет со всех: человек начал бы писать вычисленное значение дня
/// руками, а следующий пересчёт молча его затирал бы. Здесь пишется не
/// значение дня, а величина в журнал; значение дня из неё считает приложение
/// (`computed.lapse-score#2`).
///
/// Виджет тот же самый — портированный [NumberDialog], со своими надписями и
/// своей клавиатурой. Новых строк локализации ввод не приносит.
Future<int?> askLapseAmount(
  BuildContext context, {
  required core.HabitDefinition definition,
  required core.Preferences preferences,
  required core.Color color,
}) async {
  final NumberDialogResult? result = await showNumberDialog(
    context,
    // Открывается на нуле, как всякая незаполненная запись
    // (`number-dialog.popup#4`), а не на допуске: предзаполненные «30» человек
    // подтвердил бы не глядя, и получилась бы величина, которая обещание
    // держит, в ответ на «я сорвался».
    value: 0,
    notes: '',
    // NumberDialog красит только кнопки булевого ряда, которого здесь нет;
    // цвет передаётся тем же, каким его передаёт портированный попап числа
    // (`number-dialog.popup#1`).
    color: color,
    preferences: preferences,
  );
  if (result == null) return null;

  // Журнал хранит целые единицы, и меньше одной он не хранит вовсе
  // (`computed.lapses#2`): ноль удовлетворяет «не больше допуска» при любом
  // допуске, то есть означает «ничего не было», а это молчание — отсутствие
  // строки, а не строка с нулём. Ответ «ноль» поэтому равен отказу.
  final int amount = result.value.round();
  return amount < core.LapseRepository.minimumAmount ? null : amount;
}
```

- [ ] **Шаг 4: одна дверь на все три жеста**

В `app/lib/ui/habits/abstinence/abstinence_gestures.dart`, рядом с
`setLapseDay`:

```dart
/// Жест «сорвался» / «не сорвался» целиком: спрашивает величину, когда допуск
/// её требует, пишет и отвечает, записал ли.
///
/// Одна дверь на все три жеста — ячейку списка, кнопку карточки и день в
/// календаре, — потому что «спрашивать или не спрашивать» есть правило
/// привычки, а не свойство места, откуда по ней попали. Развести это по трём
/// местам значит завести три правила, из которых совпадать будут два.
///
/// Ответ нужен вызывающему: панель красит ячейку до записи, и «ничего не
/// записано» она обязана уметь отменить.
Future<bool> toggleLapseDay(
  BuildContext context,
  AppScope scope, {
  required core.Habit habit,
  required core.HabitDefinition definition,
  required core.LocalDate date,
  required bool lapsed,
  required core.Theme theme,
}) async {
  // Снятие величины не имеет: «этого не было» — не количество.
  if (!lapsed) {
    return setLapseDay(scope, habit: habit, date: date, lapsed: false);
  }
  // Допуск ноль — умолчание: тап и есть весь факт, и одна единица есть всё,
  // что он может значить (`computed.lapses#2`).
  if (core.abstinenceAllowanceOf(definition) <= 0) {
    return setLapseDay(scope, habit: habit, date: date, lapsed: true);
  }
  final int? amount = await askLapseAmount(
    context,
    definition: definition,
    preferences: scope.preferences,
    color: theme.colorOf(const core.PaletteColor(0)),
  );
  if (amount == null) return false;
  return setLapseDay(
    scope,
    habit: habit,
    date: date,
    lapsed: true,
    amount: amount,
  );
}
```

и импорты `package:flutter/widgets.dart` и `abstinence_amount_dialog.dart`.

- [ ] **Шаг 5: перевести оба существующих жеста на неё**

Календарь на неё встанет сразу, Задачей 38. Здесь переводятся два, которые уже
написаны.

В `app/lib/ui/habits/list/habit_list_screen.dart`, в `_buildCard`, заменить
колбэк:

```dart
      onLapse: (core.LocalDate date, bool lapsed) => toggleLapseDay(
        context,
        _model.scope,
        habit: habit,
        definition: model.abstinenceDefinitionOf(habit)!,
        date: date,
        lapsed: lapsed,
        theme: theme,
      ),
```

`!` здесь безопасен и назван: колбэк существует только у карточки, которой
`abstinenceDefinitionOf` уже ответил не-null — тем же вызовом, что двумя
строками выше отдаёт `abstinenceDefinition:`.

В `app/lib/ui/habits/abstinence/abstinence_section.dart`, в
`AbstinenceCounterCard`:

```dart
      onToggleToday: () async {
        final bool written = await toggleLapseDay(
          context,
          scope,
          habit: habit,
          definition: definition,
          date: today,
          lapsed: !lapsedToday,
          theme: theme,
        );
        if (written) onChanged();
      },
```

`onChanged` теперь под условием: перерисовывать экран, когда ничего не
записано, незачем, и надпись на кнопке от этого не поменяется.

- [ ] **Шаг 6: запустить всё, что могло сдвинуться**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test \
  test/ui/habits/abstinence/ \
  test/ui/habits/list/ \
  test/ui/habits/show/ \
  test/ui/sleep/calendar_editor_guard_test.dart
```
Ожидается PASS. `computed_list_edit_test.dart` и `calendar_editor_guard_test.dart`
обязаны остаться зелёными **дословно**: их определение сохранено без
`committedFrom`, признака нет, и ни один жест воздержания не включается.

- [ ] **Шаг 7: мутации**

| Мутация | Что обязано упасть |
|---|---|
| `if (core.abstinenceAllowanceOf(definition) <= 0)` → `if (true)` (никогда не спрашивать) | «двадцать минут… обещание держат»: `NumberDialog` не найден, а в журнал уедет 1 |
| та же строка → `if (false)` (спрашивать всегда) | «при допуске ноль вопроса нет» |
| убрать раннюю ветку `if (!lapsed)` | «снятие срыва величины не спрашивает» |
| `return amount < core.LapseRepository.minimumAmount ? null : amount;` → `return amount;` | «ноль — это молчание, а не срыв»: `save` бросит `ArgumentError` (`computed.lapses#2`) |
| `if (result == null) return null;` → `return 1;` | «вопрос без ответа фактом не становится» |
| `amount: amount` в `setLapseDay` → без него | «двадцать минут… обещание держат»: в журнал уедет 1, ячейка станет крестом, счётчик — нулём, и разойдутся все трое |
| `value: 0` → `value: core.abstinenceAllowanceOf(definition)` | не ловится набором — предзаполнение видно только человеку; решение записано в доке `askLapseAmount` и мутацией не закрывается |
| `if (written) onChanged();` → `onChanged();` безусловно | не ловится — лишняя перерисовка не видна; оставить как известный предел |

- [ ] **Шаг 8: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add app
git commit -m "Ask for the amount when the allowance calls for one"
```

---

### Task 38: календарь-редактор пишет срыв (4-ui-list.6)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/habits/show/abstinence_calendar_test.dart`

**Interfaces:** Consumes — `_lastClickedDate`, `_abstinenceDefinition`,
`toggleLapseDay` (Задача 37), `isAbstinenceLapseDay` (Задача 33). Produces —
ничего нового.

Календарь — третье и последнее место, где жест решает «срыв или нет», и судит
он тем же предикатом, что ячейка и кнопка карточки. Ввод величины он получает
даром: жест уходит в ту же `toggleLapseDay`, которая при ненулевом допуске
спрашивает «сколько», а при нулевом не спрашивает ничего.

1. Тест первым. Геометрия ячейки взята у соседа —
   `app/test/ui/sleep/calendar_editor_guard_test.dart:130-142`; здесь она
   повторена, потому что тот файл про запрет, а этот про дверь.

```dart
/// Календарь на экране воздержания: тот же жест, что и в ячейке списка.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_cal');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Habit addAbstinence() {
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
        // Достаточно давно, чтобы любая видимая клетка была уже под
        // обязательством.
        committedFrom: getToday().daysSince2000 - 400,
      ),
    );
    habit.recompute();
    return habit;
  }

  final Finder chartFinder = find.descendant(
    of: find.byType(HistoryEditorDialog),
    matching: find.byType(CoreView),
  );

  Offset cellAt(WidgetTester tester, {int col = 3, int row = 3}) {
    const double padding = HistoryEditorDialog.chartPadding;
    final Size size = tester.getSize(chartFinder);
    final double square = ((size.height - 2 * padding) / 8.0).roundToDouble();
    return tester.getTopLeft(chartFinder) +
        Offset(padding + (col + 0.5) * square, padding + (row + 0.5) * square);
  }

  Future<void> openEditorAndTapADay(WidgetTester tester, Habit habit) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(
          key: ValueKey<String?>(habit.uuid),
          habit: habit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
  }

  testWidgets('computed.abstinence-screen#6 тап по дню записывает срыв, а не '
      'открывает число', (tester) async {
    final Habit habit = addAbstinence();

    await openEditorAndTapADay(tester, habit);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
    final int? day = scope.lapses.lastDay(habit.id!);
    expect(day, isNotNull, reason: 'computed.abstinence-screen#6');
    expect(day, lessThan(getToday().daysSince2000),
        reason: 'computed.abstinence-screen#6 — срыв записан на ту клетку, по '
            'которой попали, а не на сегодня');

    // Второй тап по той же клетке снимает срыв — как в списке.
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#6');
  });
}
```

> Пути проверены по `app/test/ui/sleep/calendar_editor_guard_test.dart`:
> диалог живёт в `package:uhabits/ui/common/dialogs/history_editor_dialog.dart`,
> `HistoryEditorDialog.chartPadding` есть 10.0. Если тест не поднимает
> биндинг сам, добавить первой строкой `main()`
> `TestWidgetsFlutterBinding.ensureInitialized();` — как в том же файле.

2. Запустить — падает: `lastDay` остаётся null, потому что запрет сегодня
   просто уходит `return`.

3. В `showNumberPopup`, внутри ветки `if (_isComputed) {`, сразу после
   `callback.onNumberPickerDismissed();`:

```dart
      // Воздержание: тот же жест, что и в ячейке списка. Числа человек не
      // вводит, но «в этот день я сорвался» — не измерение, а факт, и его
      // дверь — журнал срывов (`computed.abstinence-screen#6`).
      final core.HabitDefinition? definition = _abstinenceDefinition;
      if (definition != null) {
        final core.LocalDate? day = _lastClickedDate;
        if (day == null || day.daysSince2000 < definition.committedFrom!) {
          return;
        }
        final int stored = widget.habit.originalEntries.get(day).value;
        // Пропуск — отметка человека; `DayWriter` его не перепишет, и здесь
        // тоже (`computed.abstinence-cell#4`).
        if (stored == core.Entry.skip) return;
        // Тот же судья, что у ячейки и у кнопки карточки: «есть запись в дне»
        // при допуске 30 сняло бы двадцать минут, которые срывом не были.
        unawaited(toggleLapseDay(
          context,
          widget.scope,
          habit: widget.habit,
          definition: definition,
          date: day,
          lapsed: !isAbstinenceLapseDay(definition, stored),
          // `coreThemeOf(context)` — тот же способ, каким тему берут соседние
          // `showNumberPopup` и `_showCheckmarkPopup` в этом же файле
          // (`show_habit_screen.dart:553`, `:559`).
          theme: coreThemeOf(context),
        ).then((bool written) {
          if (written && mounted) _repaintComputed();
        }));
        return;
      }
```

и импорты
`import '../abstinence/abstinence_button_view.dart' show isAbstinenceLapseDay;`,
`import '../abstinence/abstinence_gestures.dart';` (плюс `dart:async` ради
`unawaited`, если его в файле ещё нет).

4. Прогнать новый тест и `test/ui/sleep/calendar_editor_guard_test.dart`.
   Второй остаётся зелёным дословно: его воздержание сохранено без
   `committedFrom`, ветка не срабатывает, и жест по-прежнему упирается в отказ.

5. Мутации:

| Мутация | Падает |
|---|---|
| `date: day` → `date: core.getToday()` | `#6` (день не тот) |
| `lapsed: !isAbstinenceLapseDay(definition, stored)` → `lapsed: true` | `#6` (второй тап не снимает) |
| `isAbstinenceLapseDay(definition, stored)` → прежний `stored > core.Entry.skip` | не ловится этим тестом (допуск ноль) — ловится тестом допуска 30 из Задачи 37, где календарь спрошен третьим |
| убрать проверку `day.daysSince2000 < definition.committedFrom!` | не ловится этим тестом (обещание 400 дней назад) — оставить, её ловит `computed.abstinence-cell#3` в панели |
| поставить блок воздержания **после** ветки сна | не ловится — у воздержания нет цели сна; порядок оставить как написано |

6. Коммит: `abstinence: календарь-редактор пишет срыв за выбранный день`.

---

### Task 39: отступления секции списка и экрана привычки (4-ui-list.8)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`

**Interfaces:** ничего не даёт коду; закрывает бухгалтерию секции списка и
экрана привычки.

Восемь задач секции правят портированный UI, и до этой задачи ни одна не пишет
в реестр отступлений ни строки. При этом `entry_panel.dart` получает третий вид
ячейки и второй колбэк (правила `list-habits.entry-panels#5` и `#10` описывают
ровно две панели), `habit_card.dart` — новые поля, портированный `NumberDialog`
получает второй, необщий вход (Задача 37), а карточка «дней без срыва» встаёт
**выше** Subtitle, хотя `show-habit.card-order-and-visibility#1` перечисляет
порядок дословно.

- [ ] **Шаг 1: записать отступление секции**

В `docs/parity/DEVIATIONS.md`, в раздел `## Расширения`, дописать:

```markdown
### computed: ячейка и колонка привычки-воздержания

**Каких правил касается:** `list-habits.entry-panels#5`,
`list-habits.entry-panels#10`, `list-habits.habit-card`,
`show-habit.card-order-and-visibility#1`. Правило
`show-habit.card-order-and-visibility#2` не затрагивается: замена карточки цели
на кольцо у вычисляемой привычки уже записана как отступление сна и здесь лишь
обобщена со сна на любой вычисляемый вид.

**Что в оригинале:** панель дней знает два вида ячеек — галочку и число, — и
значение кнопки есть `values[i + dataOffset]`, а для числовой панели ещё и
цель, порог и единица. Колонка экрана привычки начинается карточкой Subtitle и
идёт дальше в перечисленном порядке.

**Что делаем:** панель получает третий вид ячейки, `AbstinenceButtonView`, и
второй колбэк, `onLapse`. Включает его непустой `committedFrom` у определения
вида `abstinence` — не `isNumerical`, потому что воздержание **есть** числовая
привычка и по типу неотличимо от «прочитано страниц». Экран привычки ставит
карточку «дней без срыва» выше Subtitle. Портированный `NumberDialog` получает
второй вход — `askLapseAmount`, — минуя `showNumberPopup`: та дверь закрыта
охраной вычисляемых привычек и остаётся закрытой, а здесь человек вводит не
значение дня, а величину в журнал (`computed.abstinence-cell#8`). Сам виджет
диалога не меняется ни строкой.

**Почему нельзя было обойтись портом:** числовая ячейка нарисовала бы «0» серым
в каждый день, которого человек не отмечал, — величину, которой он не вводил, в
цвете «мимо цели», — и по тапу просила бы ввести число, что вычисляемой
привычке запрещено (`computed.write-paths#3`). Карточка ниже Subtitle: у сна
собственные блоки есть механика, а «сорок дней без срыва» — сама привычка,
ради этой строки экран и открывают.

**Влияние на пользователя:** none для привычек оригинала. Оба признака — третий
вид ячейки и порядок колонки — включаются только непустым днём обязательства;
привычка без него ведёт себя дословно как раньше, и портированные тесты
`list-habits.entry-panels`, `list-habits.habit-card` и
`show-habit.card-order-and-visibility` проходят без единой правки.

**Дата:** 2026-08-27
```

- [ ] **Шаг 2: записать оба отказа — одной записью**

Спецификация требует, чтобы решение по виджетам и по карточкам Bar и Frequency
было принято **явно**. Оно принято: ни то, ни другое в эту работу не входит.
Молчание об этом было бы неотличимо от забывчивости, поэтому отказ пишется в тот
же реестр, следующей записью:

```markdown
### computed: воздержание не трогает виджеты, Bar и Frequency

**Каких правил касается:** ни одного — это запись о том, чего решено **не**
делать, и о цене этого решения.

**Виджеты.** Документ виджета не меняется: поле не добавляется, `schemaVersion`
не поднимается, три файла и `WidgetToggleQueue.schemaVersion` остаются как есть.
Виджет привычки-воздержания показывает ровно то же, что виджет любой числовой
привычки, — «0» в чистый день и «45000» в день срыва. Тап по нему записи не
делает: охрана `WidgetBehavior.setValue` отказывает вычисляемой привычке
независимо от вида (`computed.write-paths#1`), и это проверено тестом
«the widget, the notification and the queue write nothing here».

**Bar и Frequency.** Карточки остаются на экране и продолжают складывать
значения дней как проценты. Скрывается только карточка цели, и только она
(`computed.abstinence-screen#4`). Спецификация выносит решение по Bar и
Frequency отдельно и прямо, и здесь оно принято так: отложить, а не сделать
наполовину. Тест `expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.bar)),
findsOneWidget)` в наборе экрана держит это как решение, а не как забывчивость:
когда карточки решат прятать, падёт именно он.

**Влияние на пользователя:** виджет воздержания выглядит как виджет числовой
привычки; две карточки на экране показывают величины в шкале, для которой они
не задуманы. Обе цены приняты сознательно и обе видны на экране, а не в данных:
ничего не теряется и не портится.

**Дата:** 2026-08-27
```

- [ ] **Шаг 3: проверить, что портированное не сдвинулось**

```bash
cd /Users/artemefimov/Desktop/uhabits
git diff --stat docs/parity/FEATURES.md
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app
flutter test test/ui/habits/list/ test/ui/habits/show/
```
Первая команда обязана напечатать пустоту, вторая — зелено **без единой правки**
в портированных наборах.

- [ ] **Шаг 4: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits
git add docs/parity/DEVIATIONS.md
git commit -m "Record the abstinence cell, the card order and both refusals"
```

---

### Task 40: закрыть правила ячейки и экрана (4-ui-list.7)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`

**Interfaces:** Consumes — тесты Задач 33–39. Produces — закрытые группы
`computed.abstinence-cell`, `computed.abstinence-screen`.

1. Поменять `- [ ]` на `- [x]` у обеих групп.

2. Проверить, что каждое правило действительно процитировано:

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
dart tool/parity_coverage.dart --verify
dart tool/parity_coverage.dart --uncited | grep abstinence
```

Первая команда обязана напечатать `Every checked feature is fully cited.`,
вторая — ничего.

3. Мутация: убрать `reason: 'computed.abstinence-cell#3'` из одного `expect` —
   `--verify` обязан выйти с кодом 1 и назвать это правило. Вернуть обратной
   текстовой заменой.

4. Полный прогон и анализ:

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter analyze && flutter test
```

5. Коммит: `docs: правила ячейки и экрана воздержания закрыты тестами`.

### Task 41: хук 8 — «смена вида невозможна» перестаёт быть про сон (6-hooks.7)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/computed_kind_is_final_test.dart` (create)

**Interfaces:**
- Produces: ничего в коде. Правило `computed.definition#10` и механическая
  проверка отсутствия обратного хода.

Спецификация требовала: смена вида либо реализуется, либо документируется как
невозможная. Выбрано второе, и запись отклонений это фиксирует — но фиксирует
словами про сон: «привычку, заведённую как обычную, нельзя превратить в привычку
со сном». С воздержанием утверждение то же, а текст мимо. И главное: сегодня оно
держится на наблюдении «`DefinitionRepository.remove` не зовёт ни один путь
приложения», которое верно ровно до первого коммита, который его позовёт.

**Шаги:**

1. Написать падающий тест. Создать
   `app/test/state/computed_kind_is_final_test.dart`:

```dart
/// `computed.definition#10` — вычисляемость задаётся при создании и не снимается.
///
/// Это не договорённость, а наблюдение о коде: пути «обычная → вычисляемая» на
/// существующей привычке нет, и пути обратно нет тоже — `remove` в репозитории
/// определений не зовёт никто, кроме собственного теста. Наблюдение живёт ровно
/// до первого коммита, который его нарушит, поэтому оно здесь и механическое.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file the application and the core actually ship.
Iterable<File> shippedSources() sync* {
  for (final String root in <String>[
    'lib',
    '../packages/uhabits_core/lib',
  ]) {
    final Directory directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final FileSystemEntity entity
        in directory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }
}

/// Снятие метки — по типу, а не по имени переменной.
///
/// `final repo = scope.definitions; repo.remove(id);` — тот же путь, и поиск по
/// строке `definitions.remove(` его не видит. Регулярка ловит любое имя,
/// оканчивающееся на `definition`/`definitions`/`definitionRepository`, и
/// заодно прямой `delete from HabitDefinitions`.
final RegExp takesTheMarkOff = RegExp(
  r'[Dd]efinition[sR]?[A-Za-z]*\s*\.\s*remove\s*\(|'
  r'delete\s+from\s+HabitDefinitions',
);

void main() {
  test('the search would find the call if it were there', () {
    // Иначе регулярка, сломанная опечаткой, даёт вечнозелёный тест: он ищет
    // то, чего не может найти, и всегда доволен.
    expect(
        takesTheMarkOff
            .hasMatch('final r = scope.definitions;\nr.remove(1);'),
        isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch('definitionRepository.remove(id);'), isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch("db.run('delete from HabitDefinitions');"),
        isTrue,
        reason: 'computed.definition#10');
    expect(takesTheMarkOff.hasMatch('habitList.remove(habit);'), isFalse,
        reason: 'computed.definition#10 — удаление привычки меткой не '
            'является');
  });

  test('nothing that ships takes the mark off a habit', () {
    final List<String> callers = <String>[];
    for (final File file in shippedSources()) {
      final String source = file.readAsStringSync();
      // The declaration itself is not a call site.
      if (file.path.endsWith('computed/definition_repository.dart')) continue;
      if (takesTheMarkOff.hasMatch(source)) callers.add(file.path);
    }

    expect(callers, isEmpty,
        reason: 'computed.definition#10 — если появился путь, снимающий метку, '
            'запись отклонения «вид привычки после создания не меняется» '
            'больше не верна и должна быть переписана вместе с ним');
  });
}
```

   Тест запускается из `app/`, поэтому пути относительные и такие же, как у
   соседей вроде `app/test/platform/manifest_components_test.dart`.

2. Запустить:
   `cd .../app && flutter test test/state/computed_kind_is_final_test.dart`
   → сегодня зелено с первого раза. Это тот случай, когда падение показывается
   мутацией, а не отсутствием кода: временно вписать
   `scope.definitions.remove(habit.id!);` в
   `app/lib/state/edit_habit_model.dart` рядом со `save`, увидеть
   `Expected: isEmpty  Actual: ['lib/state/edit_habit_model.dart']`, и снять
   обратной текстовой заменой — не `git checkout`.

3. Переписать вторую запись отклонения в
   `/Users/artemefimov/Desktop/uhabits/docs/parity/DEVIATIONS.md`. Заголовок
   `### computed: вид привычки после создания не меняется` остаётся; меняются
   два абзаца — тот, что называет сон единственным видом, и заключительный.

   Заменить

```
Привычка становится вычисляемой ровно в одном месте — при сохранении новой
привычки, выбранной как «Сон» (`state/edit_habit_model.dart:428-434`): цель и
определение пишутся вместе.
```

   на

```
Привычка становится вычисляемой ровно в одном месте — при сохранении новой
привычки, выбранной как вычисляемый вид. Это хвост `EditHabitModel.save()`
(`state/edit_habit_model.dart`, ветка `if (goal != null) … else if
(isAbstinence) …`): он вешает на `CommandRunner` слушателя `_AfterCommand`, и
боковые строки пишет уже тот, когда команда отработала. У сна цель и
определение пишутся вместе — в `_writeSleepGoal`, куда переехали строки,
стоявшие на `:428-434` до обобщения слушателя; у воздержания — определение с
днём обязательства и допуском. Место одно на оба вида, и добавление третьего
его не раздваивает.
```

**Постановление о ссылке.** Номер `:428-434` остаётся только в **цитируемом**
куске — том, который заменяют; в новом тексте его нет. Задача 29 переносит эти
семь строк из `save()` в `_writeSleepGoal` и заводит рядом ветку воздержания,
после чего диапазон указывает не туда, а имена — туда. Запись отклонения живёт
дольше номеров строк.

   и заменить последний абзац

```
Влияние на пользователя: привычку, заведённую как обычную, нельзя превратить в
привычку со сном — и наоборот. Нужен другой вид — заводится другая привычка;
история старой остаётся при ней. Удаление привычки уносит её определение и цель
каскадом (`computed.schema#2`), так что следов не остаётся.
```

   на

```
Влияние на пользователя: привычку, заведённую как обычную, нельзя превратить в
вычисляемую — и наоборот, и вычисляемую одного вида нельзя переделать в другой.
Нужен другой вид — заводится другая привычка; история старой остаётся при ней.
Удаление привычки уносит с собой всё, что было заведено под её идентификатором:
определение, цель сна, журнал срывов (`computed.schema#2`,
`computed.lifecycle#6`), так что следов не остаётся. Что утверждение про «кода
нет ни в одну сторону» всё ещё верно, проверяется механически
(`computed.definition#10`).
```

4. Правило в `docs/extensions/COMPUTED.md`, в блок `computed.definition`:

```
10. `computed.definition#10` Ни один отгружаемый путь не снимает метку с привычки: вычисляемость задаётся при создании и не меняется.
```

5. `cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && dart tool/parity_coverage.dart --verify`

6. Полный прогон обеих сборок:
   `cd .../packages/uhabits_core && dart test`
   `cd .../app && flutter test`

7. Коммит: `hooks: state hook 8 without naming a kind`.

**Мутации:**
- вписать `scope.definitions.remove(...)` в любой файл под `app/lib` или
  `packages/uhabits_core/lib` → падает «nothing that ships takes the mark off a
  habit» с именем этого файла;
- убрать из теста строку `if (file.path.endsWith('computed/definition_repository.dart')) continue;`
  → тест начинает падать на объявлении, то есть сам показывает, что фильтр
  нужен, а не декоративен;
- сломать регулярку опечаткой (`remove` → `remoove`) → падает «the search would
  find the call if it were there», а не второй тест: без первой проверки эта
  опечатка сделала бы набор вечнозелёным.

### Task 42: CSV-экспорт журнала срывов (1-schema.6)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/lib/src/io/habits_csv_exporter.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/lib/ui/settings/data_actions.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/ui/settings/data_actions_test.dart`
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core/test/io/lapse_export_test.dart` (create)

**Interfaces:**
- Потребляет: `LapseRepository.firstDay/lastDay/range` (Задача 3),
  `AppScope.lapses` (Задача 19).
- Даёт: необязательный параметр `LapseRepository? lapseRepository` у
  `HabitsCSVExporter` и у `ExportCSVTask` — ровно той же формы, что уже стоящий
  рядом `SleepSessionRepository? sleepRepository`, — и условный файл
  `Lapses.csv` в собираемом архиве. `Habits.csv` остаётся двенадцатиколоночным
  и не меняется ни на колонку.

**Почему это в плане, а не в долгах.** Срывы — данные человека. Побайтовая копия
несёт их даром, а CSV — нет, и журнал, который нельзя вынести, есть данные в
заложниках.

**Дверь одна, и это проверено.** Экспортёр собирается ровно в одном месте на весь
репозиторий — `packages/uhabits_core/lib/src/io/habits_csv_exporter.dart:278`,
внутри `ExportCSVTask.doInBackground`:

```dart
      final exporter = HabitsCSVExporter(
        _habitList,
        _selectedHabits,
        sleepRepository: _sleepRepository,
      );
```

`grep -rn "HabitsCSVExporter(" --include="*.dart" packages/uhabits_core/lib app/lib`
находит только его. `HabitList.writeCSV()` дверью не является: это **содержимое**
`Habits.csv`, одна строка на привычку с двенадцатью колонками
(`models/habit_list.dart:112-158`), и экспортёр зовёт его сам —
`zip.addEntry('Habits.csv', allHabits.writeCSV());`. Трёх точек экспорта нет;
есть одна, и весь вопрос в том, доезжает ли до неё репозиторий.

Сама `ExportCSVTask` строится в двух местах, и они разные:

* `app/lib/ui/settings/data_actions.dart:295` — «Экспорт в CSV» из настроек, все
  привычки. Сюда репозиторий передаётся; сюда же уже передан
  `sleepRepository: scope.sleepRepository`.
* `packages/uhabits_core/lib/src/ui/screens/habits/show/show_habit_menu_presenter.dart:194`
  — «экспортировать эту привычку» из меню экрана. Портированный презентер, чья
  подпись закрыта паритетными правилами; он не передаёт и `sleepRepository`, то
  есть ночей из него сегодня тоже не выносится. Трогать его здесь не будем: это
  правка формы порта, и она принадлежит той же работе, что вернёт туда сон, а не
  этой.

**Форма файла взята у соседа, а не выдумана.** `_writeSleepSessions`
(`habits_csv_exporter.dart:74-120`) — единственный существующий пример «боковая
таблица едет своим файлом», и второй такой файл обязан читаться так же: тот же
разделитель `_delimiter`, тот же `zip.addEntry`, тот же способ напечатать день —
`LocalDate(day).toString()`.

**Про дату — прямо, потому что она удивляет.** `LocalDate.toString()` есть
`'LocalDate($year-$month-$day)'` (`time/local_date.dart:227`), без ведущих нулей
и вместе со словом `LocalDate`. Значит колонка `Day` в `SleepSessions.csv` уже
сегодня выглядит как `LocalDate(2024-8-12)`, а не как `2024-08-12`, и
`sleep_export_test.dart:168-171` это закрепляет. Второй файл того же архива
обязан печатать день **так же**: две колонки `Day` в одном архиве, набранные
по-разному, — это два формата у одного слова. Красивее было бы `toCSVString()`,
им набраны `Checkmarks.csv` и `Scores.csv`; но менять из-за нового файла формат
уже отгруженного `SleepSessions.csv` — работа не этой задачи, а её нельзя
сделать наполовину.

День 8990 — это **12 августа 2024 года** (8766 дней приходятся на конец 2023
года, остаток 224 при отсчёте от 1 января 2024 попадает в август високосного
года), и печатается он как `LocalDate(2024-8-12)`.

- [ ] **Шаг 1: написать падающий тест**

Создать `packages/uhabits_core/test/io/lapse_export_test.dart`. Обвязка взята у
соседнего `packages/uhabits_core/test/io/sleep_export_test.dart` дословно —
`entriesOf`, `contentOf`, `openAppSchemaDatabase`, `MemoryHabitList` с двумя
привычками; предмет другой, а форма та же:

```dart
/// `Lapses.csv` — журнал срывов в архиве экспорта.
///
/// Обвязка — та же, что у `sleep_export_test.dart` по соседству: архив
/// собирается в память, `entriesOf` даёт имена записей, `contentOf` — их
/// содержимое.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/zip.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

/// The names of the entries in an exported archive.
Future<Set<String>> entriesOf(Uint8List bytes) async => <String>{
      for (final ZipEntry e in await ZipReader(bytes).entries()) e.name,
    };

Future<String> contentOf(Uint8List bytes, String name) async =>
    (await ZipReader(bytes).entries())
        .firstWhere((ZipEntry e) => e.name == name)
        .content;

void main() {
  late Database db;
  late LapseRepository lapses;
  late MemoryHabitList habits;
  late Habit sober;
  late Habit run;

  setUp(() {
    setToday(LocalDate(9000));
    db = openAppSchemaDatabase();
    // Строки журнала висят на внешнем ключе, поэтому привычки должны быть в
    // базе, а не только в списке в памяти.
    db.run("insert into Habits (id, name, uuid) values (1, 'Sober', 'u1')");
    db.run("insert into Habits (id, name, uuid) values (2, 'Run', 'u2')");
    lapses = LapseRepository(db);

    habits = MemoryHabitList();
    final MemoryModelFactory factory = MemoryModelFactory();
    sober = factory.buildHabit()
      ..id = 1
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 30
      ..unit = 'minutes';
    run = factory.buildHabit()
      ..id = 2
      ..name = 'Run';
    habits.add(sober);
    habits.add(run);
  });

  tearDown(() {
    db.close();
    resetToday();
  });

  group('an archive with nothing to add', () {
    test('is exactly what it was before', () async {
      final Uint8List withRepository = await HabitsCSVExporter(
        habits,
        <Habit>[run],
        lapseRepository: lapses,
      ).writeArchive();
      final Uint8List without =
          await HabitsCSVExporter(habits, <Habit>[run]).writeArchive();

      expect(await entriesOf(withRepository), await entriesOf(without),
          reason: 'computed.backup#5');
      expect(await entriesOf(withRepository), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5 — условный файл: пустая таблица в каждом '
              'архиве была бы налогом на всех ради немногих');
    });

    test('no repository at all is not an error', () async {
      lapses.save(1, 8990, amount: 45);

      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sober]).writeArchive();

      expect(await entriesOf(bytes), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5 — экспортёр без журнала обязан вести '
              'себя как upstream, байт в байт');
    });
  });

  group('an archive with lapses in it', () {
    setUp(() => lapses.save(1, 8990, amount: 45));

    test('carries a file of its own', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      expect(await entriesOf(bytes), contains('Lapses.csv'),
          reason: 'computed.backup#5');
    });

    test('names its columns, and the row is the habit, the day, the amount',
        () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      final List<String> rows =
          (await contentOf(bytes, 'Lapses.csv')).trim().split('\n');

      expect(rows, <String>[
        'Habit,Day,Amount',
        'Sober,LocalDate(2024-8-12),45',
      ],
          reason: 'computed.backup#5 — имя привычки, день и величина; не '
              'habit id, по которому снаружи ничего не найти, и не «1», '
              'потому что «не более 30 минут» без числа не выражается');
    });

    test('the day is spelled the way SleepSessions.csv already spells it', () {
      // Не отдельная договорённость, а та же самая: `_writeSleepSessions`
      // печатает день через `LocalDate(day).toString()`, а `toString()` есть
      // `'LocalDate($year-$month-$day)'` без ведущих нулей
      // (`time/local_date.dart:227`). Две колонки `Day` в одном архиве,
      // набранные по-разному, — это два формата у одного слова.
      expect(LocalDate(8990).toString(), 'LocalDate(2024-8-12)',
          reason: 'computed.backup#5 — 8990-й день от 1 января 2000 года есть '
              '12 августа 2024 года');
    });

    test('a habit that was not selected is left out', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[run],
        lapseRepository: lapses,
      ).writeArchive();

      expect(await entriesOf(bytes), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5');
    });

    test('Habits.csv is still twelve columns', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      final String header =
          (await contentOf(bytes, 'Habits.csv')).split('\n').first;

      expect(header.split(',').length, 12,
          reason: 'computed.backup#5 — боковая таблица едет отдельным файлом; '
              'колонка, дописанная в Habits.csv, сломала бы всякий парсер '
              'снаружи');
    });
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/io/lapse_export_test.dart
```
Ожидается FAIL с именем: `Error: No named parameter with the name
'lapseRepository'.` — параметра у экспортёра ещё нет.

- [ ] **Шаг 3: написать выгрузку**

В `packages/uhabits_core/lib/src/io/habits_csv_exporter.dart` — импорт рядом с
`import '../sleep/sleep_session_repository.dart';`:

```dart
import '../computed/lapse_repository.dart';
```

конструктор `HabitsCSVExporter` — второй необязательный сотрудник рядом с
первым:

```dart
  HabitsCSVExporter(
    this.allHabits,
    this.selectedHabits, {
    this.sleepRepository,
    this.lapseRepository,
  });
```

и поле сразу за `sleepRepository`:

```dart
  /// The journal of lapses, when this build has one to export.
  ///
  /// Optional for the same reason [sleepRepository] is: a database with no
  /// abstinence habit must produce exactly the archive the original produces,
  /// byte for byte. A file the original never writes must not appear in an
  /// archive that has nothing to put in it.
  final LapseRepository? lapseRepository;
```

В `writeArchive`, следующей строкой за ночами:

```dart
    final String? sessions = _writeSleepSessions();
    if (sessions != null) zip.addEntry('SleepSessions.csv', sessions);
    final String? lapses = _writeLapses();
    if (lapses != null) zip.addEntry('Lapses.csv', lapses);
    return zip.toBytes();
```

и сам метод — сразу под `_writeSleepSessions`, потому что это его близнец:

```dart
  /// The lapses of every selected abstinence habit, or null when there are
  /// none.
  ///
  /// A file of its own rather than a column in `Habits.csv`: the habits of the
  /// original have no journal, and an empty table in every archive would be a
  /// tax on everybody for the sake of a few. `Checkmarks.csv` already carries
  /// the day values these were computed into; what cannot be reconstructed
  /// from those is the amount as it was measured, in the unit the commitment
  /// names.
  ///
  /// Written exactly as [_writeSleepSessions] is written, down to printing the
  /// day with `LocalDate.toString()`: two `Day` columns in one archive that
  /// disagree about what a day looks like would be two formats for one word.
  /// The fields go in raw, unquoted, for the same reason the sleep rows and
  /// the combined header do — upstream never quotes them, and a habit name
  /// holding a comma corrupts the row. Reproduced deliberately.
  String? _writeLapses() {
    final LapseRepository? repository = lapseRepository;
    if (repository == null) return null;

    final rows = StringBuffer();
    var any = false;
    for (final Habit habit in selectedHabits) {
      final int? id = habit.id;
      if (id == null) continue;
      final int? from = repository.firstDay(id);
      final int? to = repository.lastDay(id);
      if (from == null || to == null) continue;

      final Map<int, int> amounts = repository.range(id, from, to);
      for (final int day in amounts.keys.toList()..sort()) {
        any = true;
        rows.write(<String>[
          habit.name,
          LocalDate(day).toString(),
          '${amounts[day]}',
        ].join(_delimiter));
        rows.write('\n');
      }
    }
    if (!any) return null;

    return <String>[
      <String>['Habit', 'Day', 'Amount'].join(_delimiter),
      '\n',
      rows.toString(),
    ].join();
  }
```

Тем же файлом, в `ExportCSVTask`, — второй необязательный сотрудник и его
передача в единственную дверь (`habits_csv_exporter.dart:278`):

```dart
  ExportCSVTask(
    this._habitList,
    this._selectedHabits,
    this._outputDir,
    this._listener, {
    SleepSessionRepository? sleepRepository,
    LapseRepository? lapseRepository,
  })  : _sleepRepository = sleepRepository,
        _lapseRepository = lapseRepository;
```

```dart
  /// Optional, so that a caller with nothing to add produces exactly the
  /// archive the original produces.
  final SleepSessionRepository? _sleepRepository;

  final LapseRepository? _lapseRepository;
```

```dart
      final exporter = HabitsCSVExporter(
        _habitList,
        _selectedHabits,
        sleepRepository: _sleepRepository,
        lapseRepository: _lapseRepository,
      );
```

- [ ] **Шаг 4: запустить ядро**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core
dart test test/io/
```
Ожидается PASS целиком, включая портированные наборы экспорта **без единой
правки**: `Habits.csv` не изменился, а нового файла в их архивах не появляется —
`lapseRepository` там не передан.

- [ ] **Шаг 5: провести репозиторий до двери**

Проводка есть половина двери: без неё экспортёр молча соберёт архив без журнала,
и ядровой набор выше об этом ничего не скажет. В
`app/lib/ui/settings/data_actions.dart`, в `exportCsv()` (строки 294–310), рядом
со стоящим там `sleepRepository:`:

```dart
      ExportCSVTask(
        scope.habitList,
        selected,
        outputDir,
        // The nights themselves, which the percentages in Checkmarks.csv
        // cannot be turned back into.
        sleepRepository: scope.sleepRepository,
        // And the amounts themselves, which the day values cannot be turned
        // back into either: 45000 is a number, "45 minutes" is the fact.
        lapseRepository: scope.lapses,
        _ExportCsvListener((String? filename) {
```

Портированный презентер (`show_habit_menu_presenter.dart:194`) не трогается: он
не передаёт и `sleepRepository`, его подпись закрыта паритетными правилами, и
экспорт одной привычки из меню экрана боковых файлов не несёт — ни сна, ни
срывов. Это ограничение называется в правиле, а не замалчивается.

Тест проводки — в `app/test/ui/settings/data_actions_test.dart`, рядом с уже
стоящими там тестами `exportCsv()`:

```dart
    test('computed.backup#5 the exported archive carries the lapse journal',
        () async {
      final scope = openScope();
      final habit = scope.modelFactory.buildHabit()
        ..name = 'Sober'
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 0
        ..unit = '';
      scope.habitList.add(habit);
      scope.lapses.save(habit.id!, getToday().daysSince2000, amount: 45);

      final sharer = _RecordingSharer();
      final built = buildActions(scope, pickedPath: null, fileSharer: sharer);
      await built.actions.exportCsv();

      final Uint8List bytes = File(sharer.shared.single.path).readAsBytesSync();
      final Set<String> names = <String>{
        for (final ZipEntry e in await ZipReader(bytes).entries()) e.name,
      };

      expect(names, contains('Lapses.csv'),
          reason: 'computed.backup#5 — «экспортёр умеет» и «экспорт выносит» '
              'это разные утверждения, и второе держится на этой строке');
    });
```

Импорты для него: `dart:typed_data` и `package:uhabits_core/src/io/zip.dart`
(файл уже несёт `dart:io` и `// ignore_for_file: implementation_imports`).

- [ ] **Шаг 6: запустить обе сборки**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core && dart test test/io/
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter test test/ui/settings/
```
Ожидается PASS.

- [ ] **Шаг 7: мутации**

Каждую вносить обратной текстовой заменой и такой же заменой возвращать.

| Мутация | Что обязано упасть |
|---|---|
| убрать `lapseRepository: scope.lapses,` из `data_actions.dart` | «the exported archive carries the lapse journal» — ядровой набор остаётся зелёным, и в этом весь смысл отдельного теста проводки |
| убрать `lapseRepository: _lapseRepository,` из вызова на `habits_csv_exporter.dart:278` | она же: репозиторий доехал до задачи и не доехал до двери |
| `return any ? … : null;` → `return out;` (писать файл всегда) | «is exactly what it was before» и «a habit that was not selected is left out» |
| `LocalDate(day).toString()` → `LocalDate(day).toCSVString()` | «names its columns, and the row is the habit, the day, the amount»: строка станет `Sober,2024-08-12,45` |
| `'${amounts[day]}'` → `'1'` | она же: строка станет `Sober,LocalDate(2024-8-12),1` |
| `habit.name` → `'$id'` | она же: строка станет `1,LocalDate(2024-8-12),45` |
| `.join(_delimiter)` → `.join(';')` | она же: разделитель у двух файлов одного архива обязан быть один |
| дописать тринадцатую колонку в `HabitList.writeCSV` | «Habits.csv is still twelve columns» |

- [ ] **Шаг 8: записать правило**

В `docs/extensions/COMPUTED.md`, в блок `computed.backup`, дописать:

```markdown
5. `computed.backup#5` CSV-экспорт из настроек выносит журнал срывов отдельным файлом `Lapses.csv` — имя привычки, день и величина; `Habits.csv` не меняется ни на колонку, а файла не появляется, когда журнала нет. Экспорт одной привычки из меню её экрана боковых файлов не несёт — ни этого, ни `SleepSessions.csv`: подпись портированного презентера закрыта паритетом.
```

**Постановление:** номер `#5` в блоке `computed.backup` свободен — сверка
постановила не заводить его для «величины срыва» (она вошла в текст `#4`), — и
занимается здесь. Двух правил с одним номером не возникает.

- [ ] **Шаг 9: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add packages/uhabits_core app ../docs/extensions/COMPUTED.md
git commit -m "Export the lapse journal to CSV"
```

---

### Task 43: путь целиком: заведение → срыв → отмена → перезапуск → копия → удаление (6-hooks.9)

**Files:**
- Test: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/app/test/state/abstinence_lifecycle_test.dart` (create)

**Interfaces:**
- Потребляет: `AppDatabase.openAndMigrate`, `AppScope.open/close`,
  `EditHabitModel` (Задачи 25–30), `AppScope.abstinence` (Задача 24),
  `AppScope.lapses` (Задача 19), `daysWithoutLapse` (Задача 16),
  `buildGenericImporter` (Задача 22).
- Даёт: ничего в коде. Задача есть доказательство, и код она добавляет только
  если доказательство провалилось.

**Зачем.** Каждая предыдущая задача проверяет свой стык. Ни одна не закрывает
scope и не открывает его заново на том же файле — то есть ни одна не отвечает на
вопрос, ради которого всё это писалось: то же ли увидит человек завтра утром.
Путь берётся целиком: **завёл → срыв → отмена → счётчик → перезапуск → копия →
восстановление → удаление**. Каждое звено уже проверено поодиночке; здесь
проверяется, что они соединены.

- [ ] **Шаг 1: написать тест перезапуска**

Создать `app/test/state/abstinence_lifecycle_test.dart`. Первый тест — тот, без
которого «деление пополам» живёт ровно до закрытия приложения:

```dart
  test('everything is where it was after a restart', () {
    final String path = '${tempDir.path}/habits.db';
    final AppScope first = AppScope.open(AppDatabase.openAndMigrate(path));
    final Habit habit = makeAbstinence(first, committedFrom: today - 40);
    first.abstinence.setLapse(habit, getToday().minus(3), true);
    final int days = daysWithoutLapse(habit);
    final double score = habit.scores[getToday()].value;
    final String uuid = habit.uuid!;
    first.close();

    final AppScope second = AppScope.open(AppDatabase.openAndMigrate(path));
    addTearDown(second.close);
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
```

`makeAbstinence` — та же сборка, что в `abstinence_hooks_test.dart`: числовая
привычка `atMost` с целью 0, строка `HabitDefinitions` вида `abstinence` с днём
обязательства, и `attachDefinition` + `recompute` сразу после сохранения.

- [ ] **Шаг 2: написать тест всего пути**

Вторым тестом в тот же файл — путь целиком, на одном файле базы:

```dart
  test('the whole path holds: commit, lapse, undo, restart, restore, delete',
      () async {
    final String path = '${tempDir.path}/habits.db';

    // 1. Завёл — через настоящий редактор, а не руками.
    AppScope scope = AppScope.open(AppDatabase.openAndMigrate(path));
    final EditHabitModel model =
        EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
    model.nameController.text = 'Sober';
    model.setCommittedFrom(today - 40);
    expect(model.save(), isTrue);
    Habit habit = scope.habitList.getByPosition(0);
    final String uuid = habit.uuid!;

    // 2. Счётчик существует до первой записи — ради этого весь раздел серий.
    expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');

    // 3. Срыв и 4. отмена.
    scope.abstinence.setLapse(habit, getToday(), true);
    expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#5');
    scope.abstinence.setLapse(habit, getToday(), false);
    expect(daysWithoutLapse(habit), 40,
        reason: 'computed.abstinence-sync#2 — отмена возвращает и счётчик');

    // 5. Настоящий срыв, три дня назад, и балл, который он оставил.
    scope.abstinence.setLapse(habit, getToday().minus(3), true);
    final double score = habit.scores[getToday()].value;
    expect(score, lessThan(0.9),
        reason: 'computed.lapse-score#12 — деление пополам включено на живой '
            'привычке, а не только в юнит-тесте');

    // 6. Перезапуск.
    scope.close();
    scope = AppScope.open(AppDatabase.openAndMigrate(path));
    habit = scope.habitList.getByUUID(uuid)!;
    expect(habit.scores[getToday()].value, closeTo(score, 1e-12),
        reason: 'computed.lapse-score#12');
    expect(daysWithoutLapse(habit), 2, reason: 'computed.streak#4');

    // 7. Копия и 8. восстановление на пустое устройство.
    // Копия снимается с закрытого файла: открытая база держит журнал WAL, и
    // побайтовая копия под ней — копия половины.
    scope.close();
    final UserFile backup = backupOf(path);
    final AppScope fresh =
        AppScope.open(AppDatabase.openAndMigrate('${tempDir.path}/other.db'));
    addTearDown(fresh.close);
    // `userDataDir` обязателен: в продакшне это `directories.filesDir`
    // (`app/lib/ui/settings/data_actions.dart:138` —
    // `FlutterFileOpener(userDataDir: directories.filesDir)`), здесь — тот же
    // временный каталог, в котором лежит копия.
    await buildGenericImporter(
      scope: fresh,
      fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
    ).importHabitsFromFile(backup);

    final Habit restored = fresh.habitList.getByUUID(uuid)!;
    expect(fresh.lapses.lastDay(restored.id!),
        getToday().minus(3).daysSince2000,
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
    expect(fresh.lapses.firstDay(id), isNull,
        reason: 'computed.lifecycle#6');
    expect(fresh.definitions.forHabit(id), isNull,
        reason: 'computed.lifecycle#6');
  });
```

`backupOf` — побайтовая копия файла базы во временный путь, как её снимает
экспорт. Тело выписано целиком, потому что «копия» здесь и есть предмет
проверки:

```dart
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
```

Импорты, которых требует это тело: `dart:io` (ради `File`) и
`package:uhabits_core/uhabits_core.dart` (`LocalUserFile`). Опенер, которым
импортёр открывает эту копию, требует `userDataDir`: в продакшне —
`directories.filesDir` (`app/lib/ui/settings/data_actions.dart:138`), в тесте —
`tempDir.path`.

- [ ] **Шаг 3: запустить**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app
flutter test test/state/abstinence_lifecycle_test.dart
```
Ожидается PASS. Если падает — чинить в той задаче, чей стык назван в `reason:`,
а не здесь: этот файл ничего не реализует.

- [ ] **Шаг 4: мутации**

| Мутация | Что обязано упасть |
|---|---|
| убрать `applyLapseScoring(habit, habit.definition);` из `attachDefinition` (Задача 17) | оба теста — на балле: `Expected: <0.5…> Actual: <0.948…>` |
| убрать `attachDefinitions(habitList, definitions);` из `AppScope.open` (Задача 17) | оба теста — на счётчике: после перезапуска он станет нулём или единицей |
| убрать `attachDefinitions(...)` после импорта (Задача 22, шаг 8) | «the whole path holds» на `restored.definition?.committedFrom` |
| убрать `lapseImporter:` из `buildGenericImporter` (Задача 22) | «the whole path holds» на `fresh.lapses.lastDay` |
| в `AbstinenceSync.setLapse` заменить `writer.clear` на `recomputeDays` | «the whole path holds» на шаге 4: счётчик после отмены останется нулём |

- [ ] **Шаг 5: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add app
git commit -m "Walk the whole abstinence path on one database file"
```

---

### Task 44: закрытие реестров, CHANGELOG и полный прогон (0-final)

**Files:**
- Modify: `/Users/artemefimov/Desktop/uhabits/docs/extensions/COMPUTED.md`
- Modify: `/Users/artemefimov/Desktop/uhabits/uhabits-flutter/CHANGELOG.md`

**Interfaces:** ничего не даёт коду; закрывает бухгалтерию всей работы.

- [ ] **Шаг 1: каждое правило процитировано**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
dart tool/parity_coverage.dart --uncited | grep computed.
dart tool/parity_coverage.dart --verify
```
Первая команда обязана напечатать пустоту, вторая — выйти с кодом 0. Если
названо правило без цитаты — писать тест, а не править правило.

Взведёнными к этому моменту обязаны быть все заведённые группы:
`computed.schema`, `computed.allowance`, `computed.lapses`,
`computed.abstinence-sync`, `computed.lapse-score`, `computed.commitment`,
`computed.streak`, `computed.freshness`, `computed.create`,
`computed.abstinence-cell`, `computed.abstinence-screen`, а также дополненные
`computed.lifecycle`, `computed.write-paths`, `computed.backup`,
`computed.definition`, `computed.day-write`.

- [ ] **Шаг 2: реестр отступлений сходится**

```bash
cd /Users/artemefimov/Desktop/uhabits
git diff --stat docs/parity/FEATURES.md
grep -c '^### ' docs/parity/DEVIATIONS.md
grep -n 'инвалидация после записи дня осталась сонной' docs/parity/DEVIATIONS.md
```
`FEATURES.md` не тронут ни строкой (Global Constraint 3). Записи
«computed: инвалидация после записи дня осталась сонной» больше нет — её
удалила Задача 11, потому что отступления больше не существует.

- [ ] **Шаг 3: полный прогон обеих сборок**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/packages/uhabits_core && dart test
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter/app && flutter analyze && flutter test
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter && ./test.sh
```
Ожидается `==> all green`. Отдельно убедиться, что прошли **без правок** три
портированных набора, стерегущих Global Constraints:
`app/test/models/palette_color_test.dart` и
`packages/uhabits_core/test/sleep/stored_value_test.dart` (двухэлементность
перечислений, Constraint 1) и `packages/uhabits_core/test/models/score_list_test.dart`
(поле `halvesOnLapse` не сдвинуло порт).

- [ ] **Шаг 4: строки в CHANGELOG**

```markdown
- Привычка-воздержание: чистый день не отмечается вовсе, отмечаются срывы.
  Счётчик «дней без срыва» считается со дня обязательства, срыв делит оценку
  пополам, журнал срывов переживает копию и выносится в CSV.
- Слой вычисляемых привычек перестал быть сонным: перечисление по определению,
  общий сигнал инвалидации `onComputedDataChanged`, объявление изнутри двери
  записи.
```

- [ ] **Шаг 5: коммит**

```bash
cd /Users/artemefimov/Desktop/uhabits/uhabits-flutter
git add ../docs CHANGELOG.md
git commit -m "Close the abstinence ledger"
```

