# Слой вычисляемых привычек: план реализации

> **Исполнителю:** ОБЯЗАТЕЛЬНЫЙ ПОДНАВЫК — `superpowers:subagent-driven-development`
> (рекомендуется) или `superpowers:executing-plans`. Шаги помечены `- [ ]`.

**Цель:** выразить в коде вид привычки, чьё значение дня считает приложение, —
дать ему метку, конвейер и восемь хуков жизненного цикла, — и подключить к нему
сон, оставив его вычисление нетронутым.

**Архитектура:** метка есть строка в `HabitDefinitions`; наличие строки —
единственный признак. Ни третьей записи `HabitType`, ни колонки в `Habits`.
Запись дня для такой привычки идёт через один вход, который знает про заметки,
пропуски и сентинелы. Хуки навешиваются слушателем команд в `AppScope`.

**Стек:** Dart, Flutter, `package:sqlite3` за рукописным `Database`. Тесты —
`dart test` в ядре, `flutter test` в приложении.

**Спека:** `docs/superpowers/specs/2026-08-26-computed-habits-design.md`

## Глобальные ограничения

Действуют в каждой задаче, повторять в них не нужно.

- `docs/parity/FEATURES.md` **не меняется ни одной строкой**.
- `packages/uhabits_core` **не импортирует** `package:flutter` и `dart:ui`.
- `HabitType` остаётся двухэлементным; оба теста на двухэлементность проходят без
  правки (`test/models/palette_color_test.dart:256-292`,
  `test/sleep/stored_value_test.dart:8-26`).
- Значение дня — `доля × 1000`, строго выше 3.
- Отсутствующий день остаётся отсутствующим: синтетический ноль не пишется.
- Каждое правило реестра цитируется в `expect(..., reason:)`.
- Тест не удаляется и не ослабляется ради зелёного прогона.
- Каждая правка подтверждается мутацией: ломаем правку — тест падает.
- Диапазон пересчёта вычисляемой привычки **не опирается** на
  `entries.last.date`: оригинал пишет строки `UNKNOWN`, и граница прибита.

## Что этот план не покрывает

Воздержание и перенос сна на слой условий — **отдельные планы**, и намеренно.
Их задачи потребляют интерфейсы, которые создаются здесь; план, написанный
против несуществующих сигнатур, окажется неверным ровно в тех местах, где он
нужнее всего. После этого плана: сон защищён хуками, слой готов принять второго
жителя, приложение работает.

## Карта файлов

**Создаются:**

| Файл | За что отвечает |
|---|---|
| `packages/uhabits_core/lib/src/computed/habit_definition.dart` | значение-объект определения: вид, день начала, параметры |
| `packages/uhabits_core/lib/src/computed/definition_repository.dart` | чтение и запись `HabitDefinitions` |
| `packages/uhabits_core/lib/src/computed/day_writer.dart` | единственный вход записи вычисленного дня |
| `packages/uhabits_core/lib/src/computed/definition_importer.dart` | перекладывание определений при восстановлении копии |
| `app/lib/state/computed_habit_hooks.dart` | слушатель команд: архив, удаление, снятие будильника |

**Меняются:**

| Файл | Что именно |
|---|---|
| `packages/uhabits_core/lib/src/database/extension_migrations.dart` | миграция 102, подъём `appDatabaseVersion` |
| `packages/uhabits_core/lib/src/sleep/sleep_sync.dart:229-234` | запись дня через `DayWriter` |
| `packages/uhabits_core/lib/src/io/loop_db_importer.dart` | проводка `DefinitionImporter` |
| `packages/uhabits_core/lib/src/ui/screens/habits/show/show_habit_menu_presenter.dart` | `onRandomize` закрыт |
| `app/lib/state/app_scope.dart` | репозиторий определений, фильтр архива, хуки |
| `app/lib/state/edit_habit_model.dart` | строка определения пишется вместе с целью сна |
| `app/lib/ui/settings/data_actions.dart` | проводка импортёра определений |

---

## Задача 1: заметка переживает свод

Сегодня свод сна пишет `Entry(date, value)` без заметки, и заметка человека
исчезает при каждом чтении платформы.

**Файлы:**
- Изменить: `packages/uhabits_core/lib/src/sleep/sleep_sync.dart:229-234`
- Тест: `packages/uhabits_core/test/sleep/sleep_sync_test.dart`

**Интерфейсы:**
- Потребляет: ничего.
- Даёт: ничего нового; поведение.

- [ ] **Шаг 1: написать падающий тест**

В `test/sleep/sleep_sync_test.dart`, в новую группу:

```dart
group('what a recompute leaves alone', () {
  test('a note the person wrote survives it', () async {
    habit.originalEntries
        .add(Entry(LocalDate(today), 0, notes: 'flew to Tokyo'));
    source.segments = nightOn(today, bedMinutes: 1380, asleepMinutes: 480);

    await sync.syncRecent(habit);

    expect(habit.originalEntries.get(LocalDate(today)).notes, 'flew to Tokyo',
        reason: 'computed.day-write#1');
  });
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `cd packages/uhabits_core && dart test test/sleep/sleep_sync_test.dart -N "a note the person wrote survives it"`
Ожидается: FAIL — заметка пустая.

- [ ] **Шаг 3: сохранить заметку при записи**

В `sleep_sync.dart`, там где сейчас `habit.originalEntries.add(Entry(...))`:

```dart
      // The note belongs to the person, the value belongs to the app. A
      // recompute replaces the second and must not touch the first.
      final Entry existing = habit.originalEntries.get(LocalDate(night.key));
      habit.originalEntries.add(Entry(
        LocalDate(night.key),
        breakdown.storedValue,
        notes: existing.notes,
      ));
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `dart test test/sleep/sleep_sync_test.dart`
Ожидается: PASS, вся группа зелёная.

- [ ] **Шаг 5: мутация**

Убрать `notes: existing.notes`. Тест обязан упасть. Вернуть.

- [ ] **Шаг 6: записать правило**

В `docs/extensions/SLEEP.md` добавить раздел:

```markdown
- [x] `computed.day-write`
1. `computed.day-write#1` Вычисленная запись дня сохраняет заметку человека.
```

- [ ] **Шаг 7: коммит**

```bash
git add packages/uhabits_core docs/extensions/SLEEP.md
git commit -m "Keep the note when a recompute replaces the value"
```

---

## Задача 2: архивная привычка не сводится

Портированные планировщик и трей проверяют `isArchived`; слой сна о нём не знает
и продолжает читать платформу и ставить будильники для архивной привычки.

**Файлы:**
- Изменить: `app/lib/state/app_scope.dart` (тело `_syncSleepHabits`)
- Тест: `app/test/state/sleep_sync_wiring_test.dart`

**Интерфейсы:**
- Потребляет: ничего.
- Даёт: ничего нового; поведение.

- [ ] **Шаг 1: написать падающий тест**

```dart
group('which habits are synced', () {
  test('an archived habit is left alone', () async {
    final Habit habit = addSleepHabit(name: 'Sleep');
    habit.isArchived = true;

    await scope.syncSleepHabits();

    expect(source.reads, 0, reason: 'computed.lifecycle#1');
  });
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `cd app && flutter test test/state/sleep_sync_wiring_test.dart --plain-name "an archived habit is left alone"`
Ожидается: FAIL — `reads` равно 1.

- [ ] **Шаг 3: отсеять архивные**

В `_syncSleepHabits`, сразу после `if (habit == null) continue;`:

```dart
      // The ported scheduler and tray both skip archived habits; reading the
      // platform for one is work nobody asked for, and arming its question is
      // a notification for a habit the person put away.
      if (habit.isArchived) continue;
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `flutter test test/state/sleep_sync_wiring_test.dart`
Ожидается: PASS.

- [ ] **Шаг 5: мутация**

Убрать строку `if (habit.isArchived) continue;`. Тест обязан упасть. Вернуть.

- [ ] **Шаг 6: коммит**

```bash
git add app
git commit -m "Leave archived habits out of the sleep sync"
```

---

## Задача 3: будильник снимается при удалении и архивации

`SleepPromptScheduler.cancel` не вызывается нигде. Сработавший будильник
удалённой привычки упирается в `getById(habitId)!`.

**Файлы:**
- Создать: `app/lib/state/computed_habit_hooks.dart`
- Изменить: `app/lib/state/app_scope.dart` (регистрация слушателя)
- Тест: `app/test/state/computed_habit_hooks_test.dart`

**Интерфейсы:**
- Потребляет: `SleepPromptScheduler.cancel(Habit)` из
  `app/lib/platform/sleep_prompt_scheduler.dart:57`.
- Даёт: `class ComputedHabitHooks implements CommandRunnerListener` с
  конструктором `ComputedHabitHooks({required void Function(Habit) cancelPrompt})`
  и методом `void onCommandFinished(Command command)`.

- [ ] **Шаг 1: написать падающий тест**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/computed_habit_hooks.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late List<int> cancelled;
  late ComputedHabitHooks hooks;
  late HabitList list;

  setUp(() {
    cancelled = <int>[];
    hooks = ComputedHabitHooks(
      cancelPrompt: (Habit h) => cancelled.add(h.id!),
    );
    list = MemoryHabitList();
  });

  Habit habitWith(int id) => MemoryModelFactory().buildHabit()..id = id;

  test('deleting a habit withdraws its question', () {
    final Habit habit = habitWith(7);
    hooks.onCommandFinished(DeleteHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, <int>[7], reason: 'computed.lifecycle#2');
  });

  test('archiving one does too', () {
    final Habit habit = habitWith(8);
    hooks.onCommandFinished(ArchiveHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, <int>[8], reason: 'computed.lifecycle#2');
  });

  test('un-archiving does not, because the sync arms it again', () {
    final Habit habit = habitWith(9);
    hooks.onCommandFinished(UnarchiveHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, isEmpty, reason: 'computed.lifecycle#2');
  });

  test('an ordinary command withdraws nothing', () {
    hooks.onCommandFinished(
      CreateHabitCommand(MemoryModelFactory(), list, habitWith(10)),
    );
    expect(cancelled, isEmpty, reason: 'computed.lifecycle#2');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `cd app && flutter test test/state/computed_habit_hooks_test.dart`
Ожидается: FAIL — файла `computed_habit_hooks.dart` нет.

- [ ] **Шаг 3: написать слушатель**

`app/lib/state/computed_habit_hooks.dart`:

```dart
import 'package:uhabits_core/uhabits_core.dart';

/// The lifecycle a computed habit has and a ported one does not.
///
/// A habit whose day value the app computes owns things outside the habit
/// list: a question armed with the system, rows in tables of its own. Nothing
/// in the ported command layer knows they exist, so a deleted habit used to
/// leave its question standing — and a question that fires for a habit that is
/// gone walks into `getById(habitId)!`.
///
/// A listener rather than a call at each site: deletion and archiving each
/// have several entry points, and a rule spread across them is a rule that
/// will be carried to some and not the rest.
class ComputedHabitHooks implements CommandRunnerListener {
  ComputedHabitHooks({required void Function(Habit) cancelPrompt})
      : _cancelPrompt = cancelPrompt;

  final void Function(Habit) _cancelPrompt;

  @override
  void onCommandFinished(Command command) {
    // Un-archiving deliberately withdraws nothing: the next sync arms the
    // question again, and cancelling here would race it.
    final List<Habit> gone = switch (command) {
      DeleteHabitsCommand(:final List<Habit> selected) => selected,
      ArchiveHabitsCommand(:final List<Habit> selected) => selected,
      _ => const <Habit>[],
    };
    for (final Habit habit in gone) {
      if (habit.id != null) _cancelPrompt(habit);
    }
  }
}
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `flutter test test/state/computed_habit_hooks_test.dart`
Ожидается: PASS, четыре теста.

- [ ] **Шаг 5: подключить в области**

В `app/lib/state/app_scope.dart`, в `startServices`, рядом с прочими
`startListening`:

```dart
    // Withdraws a computed habit's question when the habit goes away. Held so
    // that close() can take it off again.
    _computedHooks = ComputedHabitHooks(
      cancelPrompt: (Habit habit) =>
          unawaited(sleepPrompts?.cancel(habit) ?? Future<void>.value()),
    );
    commandRunner.addListener(_computedHooks!);
```

и в `close()`, перед `cache.cancelTasks()`:

```dart
    final ComputedHabitHooks? hooks = _computedHooks;
    if (hooks != null) commandRunner.removeListener(hooks);
    _computedHooks = null;
```

- [ ] **Шаг 6: проверить, что слушатель снимается**

Дописать в `app/test/state/app_startup_test.dart`, в группу про
`commands.command-runner-listeners#8`:

```dart
    test('the computed-habit hooks come off with the scope', () {
      final int before = scope.commandRunner.listenerCount;
      scope.close();
      expect(scope.commandRunner.listenerCount, lessThan(before),
          reason: 'computed.lifecycle#2');
    });
```

Если у `CommandRunner` нет `listenerCount`, добавить геттер
`int get listenerCount => _listeners.length;` с комментарием, что он существует
ради этой проверки.

- [ ] **Шаг 7: мутация**

Убрать `ArchiveHabitsCommand` из `switch`. Тест «archiving one does too»
обязан упасть. Вернуть.

- [ ] **Шаг 8: записать правило**

```markdown
- [x] `computed.lifecycle`
1. `computed.lifecycle#1` Архивная вычисляемая привычка не сводится и не читает платформу.
2. `computed.lifecycle#2` Удаление и архивация снимают собственный будильник вида; разархивация — нет.
```

- [ ] **Шаг 9: коммит**

```bash
git add app docs/extensions/SLEEP.md
git commit -m "Withdraw a computed habit's question when the habit goes away"
```

---

## Задача 4: таблица определений

**Файлы:**
- Изменить: `packages/uhabits_core/lib/src/database/extension_migrations.dart`
- Тест: `packages/uhabits_core/test/database/extension_migrations_test.dart`

**Интерфейсы:**
- Даёт: таблицу `HabitDefinitions(habit, kind, committed_from, payload)` и
  `appDatabaseVersion == 102`.

- [ ] **Шаг 1: написать падающий тест**

```dart
test('migration 102 creates the definitions table with a cascade', () {
  final Database db = openAppSchemaDatabase();
  addTearDown(db.close);

  expect(db.getVersion(), 102, reason: 'computed.schema#1');
  expect(
    db.queryInt("select count(*) from sqlite_master "
        "where type = 'table' and name = 'HabitDefinitions'"),
    1,
    reason: 'computed.schema#1',
  );

  // The cascade, exercised rather than read off the DDL.
  db.run("insert into Habits (id, name, description, question, freq_num, "
      "freq_den, color, position, highlight, archived, type, target_value, "
      "target_type, unit, uuid) values (1,'x','','',1,1,0,0,0,0,1,0,0,'','u')");
  db.run("insert into HabitDefinitions (habit, kind, payload) "
      "values (1,'sleep','{}')");
  db.run('delete from Habits where id = 1');

  expect(db.queryInt('select count(*) from HabitDefinitions'), 0,
      reason: 'computed.schema#2 — a habit takes its definition with it');
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `cd packages/uhabits_core && dart test test/database/extension_migrations_test.dart`
Ожидается: FAIL — версия 101, таблицы нет.

- [ ] **Шаг 3: написать миграцию**

В `extension_migrations.dart`, в карту `extensionMigrationSql`:

```dart
  102: r"""
create table HabitDefinitions (
    habit integer primary key references Habits(id) on delete cascade,
    kind text not null,
    committed_from integer,
    payload text not null
);

insert into HabitDefinitions (habit, kind, payload)
    select habit, 'sleep', '{}' from SleepGoals;""",
```

и поднять:

```dart
const int appDatabaseVersion = 102;
```

Строка `insert ... select` — это и есть проводка существующих привычек сна:
метка проставляется всем, у кого уже есть цель.

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `dart test test/database/`
Ожидается: PASS. Тест переносимости SQL
(`migration_sql_portability_test.dart`) обязан пройти без правки.

- [ ] **Шаг 5: проверить проводку существующих**

Нужна фикстура, останавливающаяся на 101. Существующие две не годятся:
`openMigratedDatabase({int version})` знает только миграции Kotlin
(`migrationSql[v]!`) и до 101 не доедет, а `openAppSchemaDatabase()` едет
сразу до конца. Добавить в `test/helpers/test_database.dart`:

```dart
/// The app schema, stopped at [version].
///
/// Exists so a migration can be tested against the schema it actually runs
/// against, rather than against the finished one.
Database openAppSchemaDatabaseAt(int version) {
  final db = openMemoryDatabase();
  db.setVersion(8);
  db.migrateTo(version, (v) => migrationSqlFor(v) ?? '');
  applyConnectionSettings(db);
  return db;
}
```

```dart
test('a habit that already had a sleep goal is marked', () {
  final Database db = openAppSchemaDatabaseAt(101);
  addTearDown(db.close);
  db.run("insert into Habits (id, name, description, question, freq_num, "
      "freq_den, color, position, highlight, archived, type, target_value, "
      "target_type, unit, uuid) values (1,'Sleep','','',1,1,0,0,0,0,1,100,0,'%','u')");
  db.run('insert into SleepGoals (habit, bed_minutes, wake_minutes, '
      'min_sleep_minutes, weight_sleep, weight_bed, weight_wake, '
      'half_credit_time_minutes, half_credit_sleep_minutes, home_utc_offset, '
      'adaptation_minutes_per_day, merge_gap_minutes, prompt_after_wake_minutes) '
      'values (1,1380,420,450,0.4,0.3,0.3,90,60,0,60,60,60)');

  db.migrateTo(102, (int v) => migrationSqlFor(v) ?? '');

  expect(db.queryInt("select count(*) from HabitDefinitions "
      "where habit = 1 and kind = 'sleep'"), 1,
      reason: 'computed.schema#3 — an existing sleep habit is not left unmarked');
});
```

- [ ] **Шаг 6: мутация**

Убрать `insert into HabitDefinitions ... select ... from SleepGoals`.
Тест шага 5 обязан упасть. Вернуть.

- [ ] **Шаг 7: записать правила**

```markdown
- [x] `computed.schema`
1. `computed.schema#1` Миграция 102 создаёт HabitDefinitions.
2. `computed.schema#2` Удаление привычки уносит её определение каскадом.
3. `computed.schema#3` Существующая привычка со сном получает метку миграцией.
```

- [ ] **Шаг 8: коммит**

```bash
git add packages/uhabits_core docs/extensions/SLEEP.md
git commit -m "Add the definitions table, and mark the sleep habits that exist"
```

---

## Задача 5: определение как значение и репозиторий

**Файлы:**
- Создать: `packages/uhabits_core/lib/src/computed/habit_definition.dart`
- Создать: `packages/uhabits_core/lib/src/computed/definition_repository.dart`
- Изменить: `packages/uhabits_core/lib/uhabits_core.dart` (экспорт)
- Тест: `packages/uhabits_core/test/computed/definition_repository_test.dart`

**Интерфейсы:**
- Потребляет: `Database` из `src/database/database.dart`.
- Даёт:
  - `enum ComputedKind { sleep, abstinence }` с полем `String get wireName`
    (`'sleep'`, `'abstinence'`) и `static ComputedKind? fromWire(String)`.
  - `class HabitDefinition` с полями `ComputedKind kind`, `int? committedFrom`,
    `Map<String, Object?> payload`; `==`, `hashCode`, `copyWith`.
  - `class DefinitionRepository` с конструктором
    `DefinitionRepository(Database db)` и методами:
    `HabitDefinition? forHabit(int habitId)`,
    `void save(int habitId, HabitDefinition definition)`,
    `void remove(int habitId)`,
    `List<int> habitIdsOfKind(ComputedKind kind)`,
    `bool isComputed(int habitId)`.

- [ ] **Шаг 1: написать падающий тест**

```dart
void main() {
  late Database db;
  late DefinitionRepository repository;

  setUp(() {
    db = openAppSchemaDatabase();
    repository = DefinitionRepository(db);
    db.run("insert into Habits (id, name, description, question, freq_num, "
        "freq_den, color, position, highlight, archived, type, target_value, "
        "target_type, unit, uuid) values (1,'x','','',1,1,0,0,0,0,1,0,0,'','u')");
  });

  tearDown(() => db.close());

  test('a habit with no definition is not computed', () {
    expect(repository.forHabit(1), isNull, reason: 'computed.definition#1');
    expect(repository.isComputed(1), isFalse, reason: 'computed.definition#1');
  });

  test('what is saved is what is read back', () {
    const HabitDefinition definition = HabitDefinition(
      kind: ComputedKind.abstinence,
      committedFrom: 9000,
      payload: <String, Object?>{'allowance': 30, 'unit': 'min'},
    );

    repository.save(1, definition);

    expect(repository.forHabit(1), definition,
        reason: 'computed.definition#2');
  });

  test('saving twice replaces rather than duplicates', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.save(1,
        const HabitDefinition(kind: ComputedKind.sleep, committedFrom: 9001));

    expect(repository.forHabit(1)!.committedFrom, 9001,
        reason: 'computed.definition#2');
    expect(db.queryInt('select count(*) from HabitDefinitions'), 1,
        reason: 'computed.definition#2');
  });

  test('a kind nobody knows reads as no definition at all', () {
    // A file written by a newer build. Guessing would be worse than admitting
    // there is nothing here this build understands.
    db.run("insert into HabitDefinitions (habit, kind, payload) "
        "values (1,'telepathy','{}')");
    expect(repository.forHabit(1), isNull, reason: 'computed.definition#3');
  });

  test('the habits of one kind are listed, and no others', () {
    db.run("insert into Habits (id, name, description, question, freq_num, "
        "freq_den, color, position, highlight, archived, type, target_value, "
        "target_type, unit, uuid) values (2,'y','','',1,1,0,0,0,0,1,0,0,'','v')");
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.save(2, const HabitDefinition(kind: ComputedKind.abstinence));

    expect(repository.habitIdsOfKind(ComputedKind.sleep), <int>[1],
        reason: 'computed.definition#4');
  });

  test('removing one leaves the habit alone', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.remove(1);

    expect(repository.forHabit(1), isNull, reason: 'computed.definition#5');
    expect(db.queryInt('select count(*) from Habits'), 1,
        reason: 'computed.definition#5');
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `dart test test/computed/definition_repository_test.dart`
Ожидается: FAIL — файлов нет.

- [ ] **Шаг 3: написать значение**

`packages/uhabits_core/lib/src/computed/habit_definition.dart`:

```dart
import 'dart:convert';

/// What kind of computation stands behind a habit.
///
/// The name goes to the database, so it is written out rather than derived
/// from the Dart identifier: renaming a field must never re-key a table.
enum ComputedKind {
  sleep('sleep'),
  abstinence('abstinence');

  const ComputedKind(this.wireName);

  final String wireName;

  /// Null for a name this build does not know — a file written by a newer
  /// one. Guessing would be worse than admitting there is nothing here.
  static ComputedKind? fromWire(String name) {
    for (final ComputedKind kind in values) {
      if (kind.wireName == name) return kind;
    }
    return null;
  }
}

/// The mark that says a habit's day value is computed, and by what.
///
/// Deliberately thin. It is a marker first and a container second: the
/// parameters of a kind live wherever that kind already keeps them — sleep
/// keeps its own in `SleepGoals` — and [payload] is for kinds that have
/// nowhere else to put a handful of numbers.
class HabitDefinition {
  const HabitDefinition({
    required this.kind,
    this.committedFrom,
    this.payload = const <String, Object?>{},
  });

  final ComputedKind kind;

  /// The day the person committed, as `daysSince2000`, or null when the kind
  /// has no such moment.
  ///
  /// It exists because the recompute range cannot be taken from the entries: a
  /// habit that records nothing while it is being kept — which is exactly what
  /// an abstinence habit does — has no oldest entry to start from.
  final int? committedFrom;

  final Map<String, Object?> payload;

  HabitDefinition copyWith({int? committedFrom, Map<String, Object?>? payload}) =>
      HabitDefinition(
        kind: kind,
        committedFrom: committedFrom ?? this.committedFrom,
        payload: payload ?? this.payload,
      );

  String get encodedPayload => jsonEncode(payload);

  static Map<String, Object?> decodePayload(String encoded) {
    if (encoded.isEmpty) return const <String, Object?>{};
    final Object? decoded = jsonDecode(encoded);
    return decoded is Map<String, Object?> ? decoded : const <String, Object?>{};
  }

  @override
  bool operator ==(Object other) =>
      other is HabitDefinition &&
      other.kind == kind &&
      other.committedFrom == committedFrom &&
      other.encodedPayload == encodedPayload;

  @override
  int get hashCode => Object.hash(kind, committedFrom, encodedPayload);

  @override
  String toString() =>
      'HabitDefinition(${kind.wireName}, from=$committedFrom, $payload)';
}
```

- [ ] **Шаг 4: написать репозиторий**

`packages/uhabits_core/lib/src/computed/definition_repository.dart`:

```dart
import '../database/database.dart';
import 'habit_definition.dart';

/// Where the mark lives.
///
/// The presence of a row is the only thing that makes a habit computed. Not a
/// third `HabitType`: adding one produces no compile error anywhere, every
/// `if (isNumerical)` falls to its else, and the habit is quietly scored as a
/// yes/no one. Not a column on `Habits`: three independent column lists and
/// the schema parity tests would have to move.
class DefinitionRepository {
  DefinitionRepository(this._db);

  final Database _db;

  HabitDefinition? forHabit(int habitId) => _db.querySingle<HabitDefinition?>(
        'select kind, committed_from, payload from HabitDefinitions '
        'where habit = ?',
        <String>['$habitId'],
        (stmt) {
          final ComputedKind? kind = ComputedKind.fromWire(stmt.getText(0));
          if (kind == null) return null;
          return HabitDefinition(
            kind: kind,
            committedFrom: stmt.getIntOrNull(1),
            payload: HabitDefinition.decodePayload(stmt.getText(2)),
          );
        },
      );

  bool isComputed(int habitId) => forHabit(habitId) != null;

  void save(int habitId, HabitDefinition definition) {
    _db.run(
      'insert into HabitDefinitions (habit, kind, committed_from, payload) '
      'values (?, ?, ?, ?) '
      'on conflict(habit) do update set '
      ' kind = excluded.kind, '
      ' committed_from = excluded.committed_from, '
      ' payload = excluded.payload',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindText(2, definition.kind.wireName);
        final int? from = definition.committedFrom;
        if (from == null) {
          stmt.bindNull(3);
        } else {
          stmt.bindInt(3, from);
        }
        stmt.bindText(4, definition.encodedPayload);
      },
    );
  }

  void remove(int habitId) => _db.run(
        'delete from HabitDefinitions where habit = ?',
        (stmt) => stmt.bindInt(1, habitId),
      );

  List<int> habitIdsOfKind(ComputedKind kind) {
    final List<int> result = <int>[];
    _db.query(
      'select habit from HabitDefinitions where kind = ? order by habit',
      <String>[kind.wireName],
      (stmt) => result.add(stmt.getInt(0)),
    );
    return result;
  }
}
```

`bindNull(int index)` есть в `Database` (`database.dart:55`), проверено.

- [ ] **Шаг 5: экспортировать**

В `packages/uhabits_core/lib/uhabits_core.dart`, рядом с экспортами сна:

```dart
export 'src/computed/definition_repository.dart';
export 'src/computed/habit_definition.dart';
```

- [ ] **Шаг 6: запустить, убедиться что проходит**

Выполнить: `dart test test/computed/`
Ожидается: PASS, шесть тестов.

- [ ] **Шаг 7: мутация**

В `fromWire` вернуть `values.first` вместо `null`. Тест «a kind nobody knows»
обязан упасть. Вернуть.

- [ ] **Шаг 8: записать правила**

```markdown
- [x] `computed.definition`
1. `computed.definition#1` Привычка без строки определения не вычисляемая.
2. `computed.definition#2` Сохранение заменяет, а не дублирует; читается ровно записанное.
3. `computed.definition#3` Незнакомый вид читается как отсутствие определения.
4. `computed.definition#4` Перечисление по виду не возвращает чужих.
5. `computed.definition#5` Удаление определения не трогает привычку.
```

- [ ] **Шаг 9: коммит**

```bash
git add packages/uhabits_core docs/extensions/SLEEP.md
git commit -m "Give a computed habit somewhere to say so"
```

---

## Задача 6: один вход для записи вычисленного дня

Сегодня запись дня разбросана: свод сна пишет сам, `SkipRange` пишет сам. Правила
— сохранить заметку, не писать синтетический ноль, не наступать на пропуск,
держаться выше сентинелов — существуют по частям.

**Файлы:**
- Создать: `packages/uhabits_core/lib/src/computed/day_writer.dart`
- Изменить: `packages/uhabits_core/lib/src/sleep/sleep_sync.dart` (использовать)
- Тест: `packages/uhabits_core/test/computed/day_writer_test.dart`

**Интерфейсы:**
- Потребляет: `Habit`, `Entry`, `LocalDate`.
- Даёт: `class DayWriter` с `const DayWriter()` и методом
  `bool write(Habit habit, int day, int? storedValue)` — возвращает, изменилось
  ли что-нибудь. `null` означает «за этот день сказать нечего», и тогда не
  пишется ничего.

- [ ] **Шаг 1: написать падающий тест**

```dart
void main() {
  const DayWriter writer = DayWriter();
  late Habit habit;

  setUp(() => habit = MemoryModelFactory().buildHabit()..id = 1);

  int valueOn(int day) => habit.originalEntries.get(LocalDate(day)).value;

  test('a value is written', () {
    expect(writer.write(habit, 9000, 89763), isTrue,
        reason: 'computed.day-write#2');
    expect(valueOn(9000), 89763, reason: 'computed.day-write#2');
  });

  test('nothing to say writes nothing at all', () {
    // Not a zero: an absent day is absent, and a written zero freezes it —
    // data arriving later can no longer heal it.
    expect(writer.write(habit, 9000, null), isFalse,
        reason: 'computed.day-write#3');
    expect(valueOn(9000), Entry.unknown, reason: 'computed.day-write#3');
  });

  test('a skipped day is left alone', () {
    habit.originalEntries.add(Entry(LocalDate(9000), Entry.skip));
    expect(writer.write(habit, 9000, 89763), isFalse,
        reason: 'computed.day-write#4');
    expect(valueOn(9000), Entry.skip, reason: 'computed.day-write#4');
  });

  test('the note is kept', () {
    habit.originalEntries.add(Entry(LocalDate(9000), 0, notes: 'kept'));
    writer.write(habit, 9000, 89763);
    expect(habit.originalEntries.get(LocalDate(9000)).notes, 'kept',
        reason: 'computed.day-write#1');
  });

  test('an unchanged value is not rewritten', () {
    writer.write(habit, 9000, 89763);
    expect(writer.write(habit, 9000, 89763), isFalse,
        reason: 'computed.day-write#5 — every write is a DELETE and an INSERT');
  });

  test('a value that would land on a sentinel is refused', () {
    // 1, 2 and 3 mean yesAuto, yesManual and skip. A computed day that landed
    // on one would read as something a person did.
    for (final int sentinel in <int>[Entry.yesAuto, Entry.yesManual, Entry.skip]) {
      expect(() => writer.write(habit, 9000, sentinel), throwsArgumentError,
          reason: 'computed.day-write#6');
    }
  });
}
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `dart test test/computed/day_writer_test.dart`
Ожидается: FAIL — файла нет.

- [ ] **Шаг 3: написать вход**

`packages/uhabits_core/lib/src/computed/day_writer.dart`:

```dart
import '../models/entry.dart';
import '../models/habit.dart';
import '../time/local_date.dart';

/// The one way a computed habit writes a day.
///
/// Four rules live here rather than at each call site, because there is more
/// than one call site and a rule spread across several of them is a rule that
/// will be carried to some and not the rest:
///
///  * the note belongs to the person and survives;
///  * a day with nothing to say stays absent — a written zero freezes it, and
///    data arriving later can no longer heal it;
///  * a day the person marked skipped is theirs, whatever was measured;
///  * a computed value never lands on 1, 2 or 3, which mean yesAuto,
///    yesManual and skip and would read as something a person did.
class DayWriter {
  const DayWriter();

  /// Writes [storedValue] for [day], and answers whether anything changed.
  ///
  /// A null [storedValue] means there is nothing to say about that day.
  bool write(Habit habit, int day, int? storedValue) {
    if (storedValue == null) return false;
    if (storedValue == Entry.yesAuto ||
        storedValue == Entry.yesManual ||
        storedValue == Entry.skip) {
      throw ArgumentError.value(
        storedValue,
        'storedValue',
        'lands on a sentinel and would read as something a person did',
      );
    }

    final LocalDate date = LocalDate(day);
    final Entry existing = habit.originalEntries.get(date);
    if (existing.value == Entry.skip) return false;
    if (existing.value == storedValue) return false;

    habit.originalEntries
        .add(Entry(date, storedValue, notes: existing.notes));
    return true;
  }
}
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `dart test test/computed/day_writer_test.dart`
Ожидается: PASS, шесть тестов.

- [ ] **Шаг 5: перевести свод сна на него**

В `sleep_sync.dart` заменить запись, сделанную в задаче 1, на:

```dart
      if (const DayWriter().write(habit, night.key, breakdown.storedValue)) {
        wrote = true;
      }
```

Проверку `existing.value == Entry.skip`, которая сейчас стоит в
`recomputeDays` отдельно, убрать: она теперь внутри и в одном месте.

- [ ] **Шаг 6: прогнать набор сна**

Выполнить: `dart test test/sleep/`
Ожидается: PASS без единой правки тестов. Если что-то падает — это
несовпадение правил, а не повод править тест.

- [ ] **Шаг 7: мутация**

Убрать `if (existing.value == Entry.skip) return false;`. Тест «a skipped day
is left alone» и тест сна `sleep.skip#6` обязаны упасть. Вернуть.

- [ ] **Шаг 8: записать правила**

```markdown
2. `computed.day-write#2` Вычисленное значение записывается.
3. `computed.day-write#3` «Сказать нечего» не пишет ничего, в том числе нуля.
4. `computed.day-write#4` Пропуск не затирается вычисленным значением.
5. `computed.day-write#5` Неизменившееся значение не переписывается.
6. `computed.day-write#6` Вычисленное значение не может попасть на 1, 2 или 3.
```

- [ ] **Шаг 9: коммит**

```bash
git add packages/uhabits_core docs/extensions/SLEEP.md
git commit -m "One door for writing a computed day"
```

---

## Задача 7: `onRandomize` закрыт для вычисляемых

`onRandomize` зовёт `originalEntries.clear()`, что в SQLite есть
`deleteByHabitId`: стирает и вычисленные значения, и пользовательские пропуски.
За пределами окна чтения этого не вернёт ничто.

**Файлы:**
- Изменить:
  `packages/uhabits_core/lib/src/ui/screens/habits/show/show_habit_menu_presenter.dart:229-248`
- Тест:
  `packages/uhabits_core/test/ui/screens/habits/show/show_habit_menu_presenter_test.dart`

**Интерфейсы:**
- Потребляет: `bool Function(int habitId)` — предикат «вычисляемая», чтобы
  презентер ядра не знал про репозиторий.
- Даёт: необязательный параметр `isComputed` у конструктора презентера.

- [ ] **Шаг 1: написать падающий тест**

```dart
test('randomising a computed habit does nothing at all', () {
  // clear() is deleteByHabitId in SQLite: it takes the computed values and
  // the person's own skips with it, and outside the read window nothing
  // brings them back.
  habit.originalEntries.add(Entry(LocalDate(9000), 89763));
  final presenter = ShowHabitMenuPresenter(
    /* ...как в соседних тестах... */
    isComputed: (int _) => true,
  );

  presenter.onRandomize();

  expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
      reason: 'computed.lifecycle#3');
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `dart test test/ui/screens/habits/show/show_habit_menu_presenter_test.dart`
Ожидается: FAIL — значение стёрто.

- [ ] **Шаг 3: закрыть**

В конструктор презентера добавить:

```dart
    /// Not upstream. Whether this habit's days are computed by the app rather
    /// than entered — for those, `onRandomize` is not a shortcut for testing
    /// but a way to lose data that cannot be recovered.
    bool Function(int habitId)? isComputed,
```

и в начало `onRandomize`:

```dart
    final int? id = habit.id;
    if (id != null && (isComputed?.call(id) ?? false)) return;
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `dart test test/ui/screens/habits/show/`
Ожидается: PASS. Портированные тесты `onRandomize` проходят без правки —
предикат по умолчанию отвечает «нет».

- [ ] **Шаг 5: проводка в приложении**

В `app/lib/state/show_habit_model.dart`, там где строится презентер меню:

```dart
      isComputed: (int id) => scope.definitions.isComputed(id),
```

- [ ] **Шаг 6: мутация**

Заменить `?? false` на `?? true`. Портированные тесты `onRandomize` обязаны
упасть. Вернуть.

- [ ] **Шаг 7: записать правило**

```markdown
3. `computed.lifecycle#3` `onRandomize` ничего не делает для вычисляемой привычки.
```

- [ ] **Шаг 8: коммит**

```bash
git add packages/uhabits_core app docs/extensions/SLEEP.md
git commit -m "Shut randomise for habits whose days the app computes"
```

---

## Задача 8: определения переживают восстановление копии

Импорт матчит привычки по uuid и раздаёт им свежие идентификаторы. Всё, что
лежит под старым, осиротеет.

**Файлы:**
- Создать: `packages/uhabits_core/lib/src/computed/definition_importer.dart`
- Изменить: `packages/uhabits_core/lib/src/io/loop_db_importer.dart`
- Изменить: `app/lib/ui/settings/data_actions.dart`
- Тест: `packages/uhabits_core/test/io/definition_import_test.dart`

**Интерфейсы:**
- Потребляет: `DefinitionRepository`, `Database`.
- Даёт: `class DefinitionImporter` с `const DefinitionImporter(DefinitionRepository)`
  и `void importFor(Database source, int? sourceHabitId, int destinationHabitId)`.
  Образец — `SleepImporter` в `src/sleep/sleep_importer.dart`.

- [ ] **Шаг 1: написать падающий тест**

По образцу `test/io/loop_db_importer_sleep_test.dart`: файл с привычкой,
у которой есть определение, и база назначения, где уже есть несколько привычек,
так что идентификаторы заведомо разойдутся.

```dart
test('a definition comes across onto the id this device gave it', () async {
  final SQLModelFactory factory = SQLModelFactory(destination);
  for (int i = 0; i < 5; i++) {
    destinationList.add(factory.buildHabit()..name = 'Mine $i');
  }
  final UserFile file = backupWithDefinition(uuid: 'abst-uuid');

  await importFile(file);

  final Habit habit = destinationList.getByUUID('abst-uuid')!;
  expect(here.forHabit(habit.id!)?.kind, ComputedKind.abstinence,
      reason: 'computed.backup#1');
  expect(here.forHabit(habit.id!)?.committedFrom, 8990,
      reason: 'computed.backup#2 — the day of the commitment travels with it');
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `dart test test/io/definition_import_test.dart`
Ожидается: FAIL — определения нет.

- [ ] **Шаг 3: написать импортёр**

`packages/uhabits_core/lib/src/computed/definition_importer.dart`:

```dart
import '../database/database.dart';
import 'definition_repository.dart';
import 'habit_definition.dart';

/// Carries the mark that makes a habit computed across a restore.
///
/// A backup is a byte-for-byte copy, so the row is always in the file. What
/// loses it is the import: habits are matched by uuid and given whatever id
/// this device has free, while the definition is filed under the id the other
/// device used. Without this the restored habit comes back an ordinary one,
/// and the loss is only noticed long after the backup has rotated away.
class DefinitionImporter {
  const DefinitionImporter(this._destination);

  final DefinitionRepository _destination;

  void importFor(Database source, int? sourceHabitId, int destinationHabitId) {
    if (sourceHabitId == null) return;
    final HabitDefinition? definition =
        DefinitionRepository(source).forHabit(sourceHabitId);
    if (definition == null) return;
    _destination.save(destinationHabitId, definition);
  }
}
```

- [ ] **Шаг 4: провести в импортёр**

В `loop_db_importer.dart`, рядом с `sleepImporter`:

```dart
  /// Not upstream, and for the same reason as [sleepImporter]: the mark that
  /// makes a habit computed is keyed by habit id, and the ids here are not the
  /// ids the file was written with.
  final DefinitionImporter? definitionImporter;
```

и в цикле, рядом с `sleepImporter?.importFor(...)`:

```dart
      definitionImporter?.importFor(db, habitData.id, habit.id!);
```

- [ ] **Шаг 5: провести в приложении**

В `app/lib/ui/settings/data_actions.dart`, в `buildGenericImporter`:

```dart
    definitionImporter: DefinitionImporter(scope.definitions),
```

- [ ] **Шаг 6: запустить, убедиться что проходит**

Выполнить: `dart test test/io/`
Ожидается: PASS.

- [ ] **Шаг 7: мутация**

Убрать `definitionImporter?.importFor(...)` из цикла. Тест обязан упасть.
Вернуть.

- [ ] **Шаг 8: записать правила**

```markdown
- [x] `computed.backup`
1. `computed.backup#1` Восстановление копии переносит определение на привычку с тем же uuid.
2. `computed.backup#2` День обязательства переносится вместе с ним.
```

- [ ] **Шаг 9: коммит**

```bash
git add packages/uhabits_core app docs/extensions/SLEEP.md
git commit -m "Carry a habit's definition through a restore"
```

---

## Задача 9: сон получает определение при создании

Метку существующим проставила миграция; новым её должен проставлять редактор.

**Файлы:**
- Изменить: `app/lib/state/edit_habit_model.dart` (внутри `_SleepGoalWriter`)
- Изменить: `app/lib/state/app_scope.dart` (поле `definitions`)
- Тест: `app/test/ui/sleep/sleep_editor_test.dart`

**Интерфейсы:**
- Потребляет: `DefinitionRepository.save`.
- Даёт: `DefinitionRepository get definitions` на `AppScope`.

- [ ] **Шаг 1: написать падающий тест**

```dart
test('a new sleep habit is marked as computed', () {
  final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
  model.nameController.text = 'Sleep';
  model.save();

  final Habit habit = scope.habitList.getByPosition(0);
  expect(scope.definitions.forHabit(habit.id!)?.kind, ComputedKind.sleep,
      reason: 'computed.definition#6');
});
```

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `cd app && flutter test test/ui/sleep/sleep_editor_test.dart`
Ожидается: FAIL — определения нет.

- [ ] **Шаг 3: завести репозиторий в области**

В `AppScope`, рядом с `sleepRepository`:

```dart
  /// Where a habit says its days are computed. See [DefinitionRepository].
  final DefinitionRepository definitions;
```

и в `AppScope.open`, где строится `sleepRepository`:

```dart
    final definitions = DefinitionRepository(database);
```

- [ ] **Шаг 4: проставлять метку вместе с целью**

В `_SleepGoalWriter.onCommandFinished`, сразу после `saveGoal`:

```dart
    // The goal is what sleep needs; the definition is what the app needs to
    // know there is anything to compute at all. Written together because a
    // habit with one and not the other is a habit half of the app can see.
    scope.definitions.save(
      saved.id!,
      const HabitDefinition(kind: ComputedKind.sleep),
    );
```

- [ ] **Шаг 5: запустить, убедиться что проходит**

Выполнить: `flutter test test/ui/sleep/`
Ожидается: PASS.

- [ ] **Шаг 6: мутация**

Убрать вызов `definitions.save`. Тест обязан упасть. Вернуть.

- [ ] **Шаг 7: записать правило**

```markdown
6. `computed.definition#6` Новая привычка со сном получает определение вместе с целью.
```

- [ ] **Шаг 8: коммит**

```bash
git add app docs/extensions/SLEEP.md
git commit -m "Mark a new sleep habit as computed when it is created"
```

---

## Задача 10: пути записи мимо команд знают о вычисляемых

Их три, а не два: `WidgetBehavior` пишет `Entry.yesManual` из виджета,
уведомления и отложенной очереди тапов без единой проверки вида. Для привычки,
чей день считает приложение, «да, сделал» — не значение, а ложь, которую следующий
свод молча перепишет.

**Файлы:**
- Изменить: `app/lib/state/widget_sync.dart:449-503`
- Изменить: `app/lib/state/intent_router.dart:229-253`
- Изменить: `app/lib/state/widget_toggle_queue.dart`
- Тест: `app/test/state/computed_write_paths_test.dart`

**Интерфейсы:**
- Потребляет: `AppScope.definitions.isComputed(int)`.
- Даёт: ничего нового; поведение.

- [ ] **Шаг 1: написать падающий тест**

```dart
void main() {
  // Каждый из трёх путей, по одному тесту, с одной и той же проверкой:
  // значение дня после попытки осталось вычисленным.
  test('a widget tap cannot mark a computed habit done', () async {
    scope.definitions.save(habit.id!,
        const HabitDefinition(kind: ComputedKind.sleep));
    habit.originalEntries.add(Entry(LocalDate(today), 89763));

    await scope.widgetSync!.toggle(habit.id!, LocalDate(today));

    expect(habit.originalEntries.get(LocalDate(today)).value, 89763,
        reason: 'computed.write-paths#1');
  });
}
```

Точные имена методов взять из `widget_sync.dart:449-503`; тест пишется против
того, что там есть, а не против того, что кажется.

- [ ] **Шаг 2: запустить, убедиться что падает**

Выполнить: `flutter test test/state/computed_write_paths_test.dart`
Ожидается: FAIL — значение стало 2.

- [ ] **Шаг 3: закрыть все три**

В каждом из трёх мест, перед записью:

```dart
      // A habit whose days the app computes has no "yes" to record: the next
      // recompute would overwrite it, so accepting the tap would be a promise
      // the app cannot keep.
      if (scope.definitions.isComputed(habitId)) return;
```

- [ ] **Шаг 4: запустить, убедиться что проходит**

Выполнить: `flutter test test/state/`
Ожидается: PASS. Портированные тесты виджетов проходят без правки — для
обычной привычки предикат отвечает «нет».

- [ ] **Шаг 5: мутация**

Убрать проверку в `widget_sync.dart`. Соответствующий тест обязан упасть.
Вернуть. Повторить для двух остальных путей — каждый закрыт своим тестом.

- [ ] **Шаг 6: записать правило**

```markdown
- [x] `computed.write-paths`
1. `computed.write-paths#1` Виджет, уведомление и отложенная очередь тапов не пишут «сделал» вычисляемой привычке.
```

- [ ] **Шаг 7: коммит**

```bash
git add app docs/extensions/SLEEP.md
git commit -m "Refuse a tap that promises what a computed habit cannot keep"
```

---

## Задача 11: сквозная проверка на устройстве

План кончается не зелёным набором, а работающим приложением.

- [ ] **Шаг 1: полный прогон**

```bash
cd packages/uhabits_core && dart test
cd ../../app && flutter analyze && flutter test
cd .. && dart tool/parity_coverage.dart --verify
bash tool/swift_tests.sh
```

Ожидается: всё зелёное, «Every checked feature is fully cited».

- [ ] **Шаг 2: миграция на живой базе**

Снять копию базы с телефона, прогнать на ней миграцию 102, убедиться что
у привычки со сном появилась строка в `HabitDefinitions`:

```bash
sqlite3 phone.db "select habit, kind, committed_from from HabitDefinitions;"
```

- [ ] **Шаг 3: поставить и проверить**

Собрать, поставить, открыть привычку со сном. Убедиться: блоки на месте,
значения прежние, ничего не пересчиталось в другую сторону.

- [ ] **Шаг 4: проверить удаление**

Создать привычку со сном, удалить её, убедиться по логу устройства, что
будильник снят и приложение не падает.

- [ ] **Шаг 5: коммит и пометка в GOAL.md**

Обновить размеры наборов в `GOAL.md`.

```bash
git add -A && git commit -m "Verify the computed-habit layer on the device"
```

---

## Самопроверка плана

Пройдено после написания:

**Покрытие спеки.** Восемь хуков спеки: заметки (задача 1), архив (2),
удаление и будильник (3), восстановление (8), инвалидация — уже существует как
`onSleepDataChanged` и в новых путях не появляется, `onRandomize` (7), пути
записи (10), смена вида — **вынесена в открытые вопросы спеки и не покрыта
здесь намеренно**: она требует решения владельца, а не кода. Метка — задачи 4,
5, 9. Конвейер — задача 6.

**Плейсхолдеры.** В задаче 10 тест написан по образцу, а не дословно: точные
имена методов трёх путей записи берутся из кода. Это единственное место, и оно
помечено явно — выдумывать сигнатуру, которую я не прочитал, было бы хуже.

**Проверено в коде, а не по памяти.** `queryInt(String sql)` берёт только SQL
(`database.dart:102`); `bindNull(int)` есть (`:55`); `openAppSchemaDatabase()`
есть, а фикстуры с остановкой на версии не было — она добавляется в задаче 4;
`CommandRunnerListener` есть `abstract interface class`, поэтому `implements`
верно (`command_runner.dart:60`).

**Согласованность имён.** `DefinitionRepository.isComputed` используется в
задачах 7, 9, 10 под одним именем. `DayWriter.write` — в 6. `ComputedKind.sleep`
— в 4, 5, 9.
