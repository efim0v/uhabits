# W0 — Сквозной скелет: план реализации

> **Для агентов:** исполнять по одной задаче, каждая заканчивается коммитом. Шаги — чекбоксы.

**Цель:** получить Flutter-приложение, которое на iOS, Android и macOS показывает список
привычек из настоящей SQLite-базы и позволяет отметить чекмарк на сегодня.

**Архитектура:** монорепо. Чистый Dart-пакет `uhabits_core` (без Flutter) содержит модели,
интерфейс `Database` и репозитории. Flutter-приложение `app` реализует интерфейсы поверх
sqflite и рисует UI. Всё остальное наращивается поверх этого скелета в волнах W1–W13.

**Стек:** Flutter 3.41.6, Dart 3.11.4, sqflite, sqflite_common_ffi, provider, test.

**Спек:** `docs/superpowers/specs/2026-08-23-flutter-migration-design.md`
**Реестр:** `docs/parity/FEATURES.md`

## Глобальные ограничения

- `packages/uhabits_core` **не импортирует** `package:flutter`. Проверяется тестом.
- Схема БД сразу содержит `uuid TEXT NOT NULL UNIQUE`, `updated_at INTEGER NOT NULL`,
  `deleted_at INTEGER` на `habits` и `entries`. Физического DELETE нет.
- Значения записей ровно как в оригинале: `SKIP=3, YES_MANUAL=2, YES_AUTO=1, NO=0, UNKNOWN=-1`
  (правила `models.entry-values#1..7`). Числовые значения хранятся ×1000.
- Тесты цитируют id правил реестра в `reason:`.
- Dart SDK ≥ 3.11.0. Ветка `flutter-migration`. Коммит после каждой задачи.

---

### Задача 1: Скелет монорепо и инвариант ядра

**Файлы:**
- Create: `uhabits-flutter/packages/uhabits_core/pubspec.yaml`
- Create: `uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Create: `uhabits-flutter/packages/uhabits_core/test/no_flutter_dependency_test.dart`
- Create: `uhabits-flutter/app/` (через `flutter create`)
- Create: `uhabits-flutter/test.sh`

**Интерфейсы:**
- Produces: пакет `uhabits_core` подключается в `app/pubspec.yaml` как path-зависимость.

- [ ] **Шаг 1: создать Dart-пакет ядра**

```bash
mkdir -p uhabits-flutter/packages/uhabits_core/lib/src
mkdir -p uhabits-flutter/packages/uhabits_core/test
```

`pubspec.yaml`: имя `uhabits_core`, `environment: sdk: ^3.11.0`, dev_dependencies `test`,
`sqflite_common_ffi`, `lints`. Зависимостей на Flutter нет и быть не может.

- [ ] **Шаг 2: написать падающий тест инварианта**

```dart
// test/no_flutter_dependency_test.dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('uhabits_core never imports Flutter', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('package:flutter/')) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: 'Core must stay pure Dart so it runs in dart test, in a sync isolate and on a server');
  });

  test('pubspec declares no Flutter dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter:'), isFalse);
  });
}
```

- [ ] **Шаг 3: прогнать — тест должен упасть на отсутствии пакета**

Run: `cd uhabits-flutter/packages/uhabits_core && dart pub get && dart test`
Expected: FAIL, пакет ещё не собран.

- [ ] **Шаг 4: создать Flutter-приложение**

```bash
cd uhabits-flutter && flutter create --org org.isoron --project-name uhabits \
  --platforms=ios,android,macos app
```

Добавить в `app/pubspec.yaml`: `uhabits_core: {path: ../packages/uhabits_core}`,
`sqflite`, `sqflite_common_ffi`, `provider`, `path_provider`.

- [ ] **Шаг 5: единый прогон тестов**

`uhabits-flutter/test.sh` запускает `dart test` в ядре и `flutter test` в приложении,
падает при любой ошибке (`set -e`).

- [ ] **Шаг 6: прогнать и закоммитить**

Run: `./uhabits-flutter/test.sh` → PASS.

```bash
git add uhabits-flutter && git commit -m "W0: scaffold uhabits_core package and Flutter app"
```

---

### Задача 2: Значения записей (`models.entry-values`)

**Файлы:**
- Create: `packages/uhabits_core/lib/src/models/entry.dart`
- Test: `packages/uhabits_core/test/models/entry_test.dart`

**Интерфейсы:**
- Produces: `class Entry {LocalDate date; int value; String notes;}`, константы
  `Entry.skip=3, Entry.yesManual=2, Entry.yesAuto=1, Entry.no=0, Entry.unknown=-1`,
  `String get formattedValue`.

- [ ] **Шаг 1: написать падающие тесты по правилам `models.entry-values#1..7`**

Каждый тест цитирует свой id в `reason:`. Обязательно включить правило #6 —
числовое значение 3 неотличимо от SKIP; это баг оригинала, который воспроизводится.

- [ ] **Шаг 2: прогнать — FAIL** · **Шаг 3: реализовать** · **Шаг 4: прогнать — PASS**
- [ ] **Шаг 5: отметить `models.entry-values` в реестре, дописать строку в PROGRESS.md, закоммитить**

---

### Задача 3: Интерфейс Database и схема v1

**Файлы:**
- Create: `packages/uhabits_core/lib/src/database/database.dart` (абстракция)
- Create: `packages/uhabits_core/lib/src/database/schema.dart` (DDL)
- Create: `app/lib/platform/sqflite_database.dart` (реализация)
- Test: `packages/uhabits_core/test/database/schema_test.dart`

**Интерфейсы:**
- Produces: `abstract class Database {Future<List<Map<String,Object?>>> query(String sql, [List<Object?> args]); Future<void> execute(...); Future<int> insert(...); Future<void> update(...);}`
  и `const schemaV1 = <String>[...]` — список DDL-стейтментов.

- [ ] **Шаг 1: написать падающий тест схемы**

Тест на `sqflite_common_ffi` создаёт БД, применяет `schemaV1` и проверяет, что у таблиц
`habits` и `entries` есть колонки `uuid`, `updated_at`, `deleted_at`, что `uuid` уникален,
и что вставка двух строк с одним uuid падает.

- [ ] **Шаг 2: FAIL** · **Шаг 3: реализовать DDL и адаптер** · **Шаг 4: PASS**
- [ ] **Шаг 5: закоммитить**

---

### Задача 4: Репозиторий привычек и записей (минимальный)

**Файлы:**
- Create: `packages/uhabits_core/lib/src/models/habit.dart`
- Create: `packages/uhabits_core/lib/src/database/habit_repository.dart`
- Create: `packages/uhabits_core/lib/src/database/entry_repository.dart`
- Test: `packages/uhabits_core/test/database/repository_test.dart`

**Интерфейсы:**
- Produces: `Habit {int? id; String uuid; String name; String question; int color; bool archived; int position;}`,
  `HabitRepository.all()`, `.insert(Habit)`, `EntryRepository.getByHabitAndDate()`, `.put(...)`.
  Каждая мутация проставляет `updated_at` в миллисекундах.

- [ ] **Шаг 1: падающие тесты** — вставка, чтение, tombstone вместо удаления, проставление `updated_at`
- [ ] **Шаг 2: FAIL** · **Шаг 3: реализовать** · **Шаг 4: PASS** · **Шаг 5: коммит**

---

### Задача 5: Экран списка и чекмарк

**Файлы:**
- Create: `app/lib/main.dart`, `app/lib/ui/habit_list_screen.dart`, `app/lib/state/habit_list_model.dart`
- Test: `app/test/habit_list_screen_test.dart`

- [ ] **Шаг 1: виджет-тест** — экран показывает имена привычек из фейкового репозитория;
      тап по кнопке переключает значение `NO → YES_MANUAL`
- [ ] **Шаг 2: FAIL** · **Шаг 3: реализовать** · **Шаг 4: PASS** · **Шаг 5: коммит**

---

### Задача 6: Запуск на трёх платформах

- [ ] **Шаг 1:** `flutter build macos --debug` и запуск
- [ ] **Шаг 2:** `flutter build ios --simulator` и запуск на iPhone 17
- [ ] **Шаг 3:** `flutter build apk --debug`
- [ ] **Шаг 4:** снять скриншоты, положить в `docs/parity/screenshots/w0/`
- [ ] **Шаг 5:** коммит

---

### Задача 7: CI

**Файлы:**
- Create: `.github/workflows/flutter.yml`

- [ ] **Шаг 1:** workflow гоняет `dart test` и `flutter test` на push и pull_request
- [ ] **Шаг 2:** коммит

---

## Критерий выхода W0

`./uhabits-flutter/test.sh` зелёный; приложение запускается на симуляторе iPhone, на
Android и на macOS; `models.entry-values` отмечена в реестре; скриншоты сняты.
