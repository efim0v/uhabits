# Цель по сну — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить в приложение третий вид привычки — суточную цель по сну с тремя составляющими, автоматическими данными из Apple Health и нелинейной оценкой.

**Architecture:** Привычка со сном — это числовая привычка с целью 100, значение записи дня равно проценту × 1000. Благодаря этому весь существующий расчёт оценки, серий, календаря и графиков работает без правок. Новое: таблица ночей, таблица целей, шесть чистых единиц в ядре (склейка, оценка, дрейф пояса, стабильность, конфигурация, репозиторий), плагин HealthKit на Swift без логики и четыре блока экрана.

**Tech Stack:** Dart 3 (ядро — без `package:flutter` и `dart:ui`), Flutter, sqlite через существующий слой `database.dart`, Swift + HealthKit, `package:test` для ядра и `flutter_test` для приложения.

**Spec:** `docs/superpowers/specs/2026-08-25-sleep-goal-design.md`

## Global Constraints

- Ядро `packages/uhabits_core` **не импортирует** `package:flutter` и `dart:ui`. Проверяется CI.
- Каждый `expect` цитирует идентификатор правила в `reason:`, например `reason: 'sleep.scoring#4'`. Идентификаторы живут в `docs/extensions/SLEEP.md`.
- `docs/parity/FEATURES.md` **не меняется ни одной строкой**. `dart tool/parity_coverage.dart --verify` обязан проходить на нём после каждой задачи.
- Тест никогда не удаляется и не ослабляется ради зелёного прогона. Если правило невыполнимо — запись в `docs/parity/DEVIATIONS.md`.
- Существующие тесты (ядро 1603, приложение 1947, Swift 19) остаются зелёными после каждой задачи.
- Крутизна логистической кривой `k = 0.05` — константа, не настройка.
- Значения записи дня 1, 2, 3 зарезервированы (`yesAuto`, `yesManual`, `skip`) и не могут быть результатом расчёта.
- Значения по умолчанию: минимум сна 450 мин, веса 0.4 / 0.3 / 0.3, половинный балл 90 мин (времена) и 60 мин (длительность), адаптация 60 мин/сутки, склейка 60 мин, утреннее напоминание через 60 мин после цели подъёма.
- Коммит после каждой задачи, в сообщении — затронутые идентификаторы правил.

---

## Что изменилось по ходу выполнения

План — документ, написанный до работы. Ниже то, в чём выполнение от него
отошло, и почему. Спецификация обновлена по каждому пункту; здесь оставлен
след, чтобы расхождение не выглядело недосмотром.

- **Третьего типа привычки нет.** Он противоречил бы паритетному правилу
  `models.habit-type-enums#1`. Привычка со сном — числовая привычка, у которой
  есть цель сна. Задача 2 переписана.
- **Оркестровка синхронизации живёт в ядре, а не в приложении.** Интерфейс
  источника — такой же порт ядра, как `Database` и `NotificationTray`, и тогда
  весь путь от отрезков до значения дня проверяется без устройства.
- **Склейка обобщена** до разложения окна в несколько ночей; выбор «главной»
  переехал в синхронизацию, которая решает это по дням.
- **Версия схемы разделена на два понятия** — последняя версия Kotlin и версия,
  которую везёт сборка. Семь мест переведены на вторую.
- **Точка входа — третья карточка в выборе типа**, сознательное отступление,
  записанное в `DEVIATIONS.md`. Плана она не касалась вовсе.
- **Добавлены три правила**, которых в плане не было: `sleep.persistence#6`,
  `#7` и `sleep.skip#6`. Первые два — про пустой промежуток версий, третье —
  про то, что пересчёт не должен стирать отмеченный пропуск.

## Что нашёл сквозной аудит

Каждая находка — дефект, которого не видел ни один тест, потому что тесты
проверяли, что код делает, а не что его кто-то вызывает.

1. **Холодный старт не синхронизировал.** Нули вместо ночей до первого
   сворачивания приложения. Найдено на симуляторе.
2. **Ручной ввод был недостижим.** Написан, покрыт тестами, не вызван ниоткуда.
3. **Разрешение у HealthKit не запрашивалось.** Вся автоматическая половина
   фичи была мертва, выглядя как отсутствие данных.
4. **Пересчёт стирал отмеченный пропуск** через день-два после того, как его
   поставили.
5. **Ячейка дня и «Ввести» в уведомлении** вели в числовой диалог, принимавший
   процент, который затирался следующим пересчётом.
6. **Незаожиданная синхронизация переживала закрытие области** и упиралась в
   закрытую базу.
7. **Три требования спецификации не были выполнены**: домашний часовой пояс,
   раздел для продвинутых, жест обновления.

## Структура файлов

**Ядро** — `packages/uhabits_core/lib/src/sleep/`, каждая единица чистая и проверяемая без базы, платформы и часов:

| Файл | Ответственность |
|---|---|
| `sleep_segment.dart` | Сырой отрезок из Health и его вид |
| `sleep_episode.dart` | Ночь как объект-значение |
| `sleep_goal.dart` | Конфигурация цели, значения по умолчанию, нормировка весов |
| `sleep_scorer.dart` | Эпизод + цель + пояс → значение записи и разбор |
| `sleep_episode_merger.dart` | Отрезки → эпизод: дедупликация источников, склейка, привязка ко дню |
| `timezone_drift.dart` | История смещений → действующий пояс по дням |
| `sleep_stability.dart` | Круговой разброс времён и средняя длительность |
| `sleep_session_repository.dart` | Доступ к `SleepSessions` и `SleepGoals` |

Изменяемые файлы ядра: `models/habit_type.dart` (третий элемент), `database/extension_migrations.dart` (новый), `database/database.dart` (двойной загрузчик миграций).

**Приложение** — `app/lib/`:

| Файл | Ответственность |
|---|---|
| `platform/health_kit_sleep_source.dart` | Dart-сторона канала |
| `state/sleep_sync.dart` | Оркестровка чтение → склейка → запись → пересчёт |
| `ui/habits/sleep/last_night_card.dart` | Блок «прошлая ночь» |
| `ui/habits/sleep/nights_chart.dart` | Лента ночей |
| `ui/habits/sleep/stability_card.dart` | Стабильность и счётчик пропусков |
| `ui/habits/sleep/manual_entry_sheet.dart` | Ручной ввод |
| `ui/habits/sleep/sleep_goal_fields.dart` | Поля редактора привычки |
| `ui/habits/sleep/skip_range_sheet.dart` | Отметка диапазона и подсказки |

**iOS** — `app/ios/Runner/HealthKitSleepPlugin.swift`, регистрация в `AppDelegate.swift`, ключи в `Info.plist`, возможность HealthKit в `project.pbxproj`.

**Документы** — `docs/extensions/SLEEP.md` (новый реестр), `tool/parity_coverage.dart` (второй реестр), `docs/parity/DEVIATIONS.md` (записи о расширениях).

---

## Фаза 1 — основание

### Task 1: Реестр расширений и проверка покрытия

Всё остальное цитирует идентификаторы отсюда, поэтому реестр идёт первым.

**Files:**
- Create: `docs/extensions/SLEEP.md`
- Modify: `uhabits-flutter/tool/parity_coverage.dart`
- Test: `uhabits-flutter/tool/parity_coverage_test.dart` (если отсутствует — создать)

**Interfaces:**
- Consumes: ничего
- Produces: идентификаторы правил вида `sleep.<область>#<номер>`, читаемые `parity_coverage.dart` наравне с паритетными

- [ ] **Step 1: Написать реестр расширений**

Создать `docs/extensions/SLEEP.md` в том же формате, что `docs/parity/FEATURES.md`: строка фичи `- [ ] \`sleep.область\``, под ней нумерованные правила. Полный список областей и правил — из спецификации:

```markdown
# Реестр расширений: цель по сну

Правила этой фичи не имеют прообраза в Kotlin. Формат совпадает с
docs/parity/FEATURES.md: `- [ ]` не закрыто, `- [x]` закрыто тестами,
`- [~]` заменено более поздним правилом.

Спецификация: docs/superpowers/specs/2026-08-25-sleep-goal-design.md

- [ ] `sleep.habit-type`
  1. `sleep.habit-type#1` HabitType.sleep имеет значение 2 и csvName 'SLEEP'.
  2. `sleep.habit-type#2` Привычка со сном всегда числовая, atLeast, цель 100, частота 1/1.
  3. `sleep.habit-type#3` Значение записи дня равно проценту, умноженному на 1000.

- [ ] `sleep.stored-value`
  1. `sleep.stored-value#1` Посчитанное значение в диапазоне 1…3 приводится к 0.
  2. `sleep.stored-value#2` Значение выше 100000 обрезается до 100000.
  3. `sleep.stored-value#3` Ноль остаётся нулём и не превращается в пропуск.

- [ ] `sleep.goal`
  1. `sleep.goal#1` Значения по умолчанию: 450 мин сна, веса 0.4/0.3/0.3, половинные баллы 90 и 60.
  2. `sleep.goal#2` Веса нормируются к сумме 1 при чтении.
  3. `sleep.goal#3` При нулевой сумме весов цель считается ненастроенной и день не оценивается.

- [ ] `sleep.scoring`
  1. `sleep.scoring#1` Отклонение времён круговое: min(|a-b|, 1440-|a-b|).
  2. `sleep.scoring#2` Отклонение длительности одностороннее: пересып не штрафуется.
  3. `sleep.scoring#3` Балл составляющей равен (1+exp(-k*m))/(1+exp(k*(d-m))) при k=0.05.
  4. `sleep.scoring#4` Балл при нулевом отклонении равен ровно 1.
  5. `sleep.scoring#5` Свёртка — взвешенное геометрическое среднее.
  6. `sleep.scoring#6` Длительность берётся как фактический сон, а не как разность подъёма и отхода.
  7. `sleep.scoring#7` Контрольные векторы из раздела 4.3 спецификации.
  8. `sleep.scoring#8` Разбор указывает составляющую с наибольшей потерей.

- [ ] `sleep.timezone`
  1. `sleep.timezone#1` Действующий пояс — чистая функция от истории наблюдённых смещений.
  2. `sleep.timezone#2` Первый день пинится к домашнему поясу.
  3. `sleep.timezone#3` Шаг задаётся наблюдением предыдущего дня, не текущего.
  4. `sleep.timezone#4` Шаг ограничен скоростью адаптации по модулю.
  5. `sleep.timezone#5` День без ночи наследует наблюдение ближайшего более раннего дня.
  6. `sleep.timezone#6` Перелёт на 7 часов отрабатывает за 7 суток по таблице раздела 5.

- [ ] `sleep.merge`
  1. `sleep.merge#1` Источники группируются по bundle id, побеждает группа с наибольшей суммой сна.
  2. `sleep.merge#2` При равенстве сумм побеждает лексикографически меньший bundle id.
  3. `sleep.merge#3` Отрезки сна, разделённые не более чем порогом склейки, объединяются в цепочку.
  4. `sleep.merge#4` Побеждает цепочка с наибольшей суммой сна, а не с наибольшим размахом.
  5. `sleep.merge#5` asleepMinutes — сумма отрезков цепочки, не её размах.
  6. `sleep.merge#6` Границы берутся из пересекающихся отрезков inBed, при их отсутствии — из цепочки, и поднимается derivedFromAsleep.
  7. `sleep.merge#7` Логический день — календарная дата пробуждения в действовавшем смещении.
  8. `sleep.merge#8` Настройка сдвига полуночи к привычке со сном не применяется.
  9. `sleep.merge#9` Ручная запись за день побеждает запись из Health.

- [ ] `sleep.stability`
  1. `sleep.stability#1` Разброс круговой: времена вокруг полуночи дают малый разброс.
  2. `sleep.stability#2` Пропуски и дни без данных исключаются.
  3. `sleep.stability#3` При числе пригодных ночей менее 4 разброс не рассчитывается.

- [ ] `sleep.persistence`
  1. `sleep.persistence#1` Миграция 100 создаёт SleepSessions и SleepGoals.
  2. `sleep.persistence#2` База версии 25 поднимается до 100 без потери привычек.
  3. `sleep.persistence#3` Повторный прогон миграции безопасен.
  4. `sleep.persistence#4` Миграции расширений отделены от сгенерированных и начинаются со 100.
  5. `sleep.persistence#5` Одна ночь на пару привычка-день.

- [ ] `sleep.sync`
  1. `sleep.sync#1` Перечитываются последние 14 дней, не только вчера.
  2. `sleep.sync#2` Свёртка идемпотентна: повторный прогон даёт те же записи.
  3. `sleep.sync#3` Смена цели пересчитывает всю историю привычки.
  4. `sleep.sync#4` Синтетический ноль не пишется никогда.
  5. `sleep.sync#5` Отказ в доступе к Health не является ошибкой.

- [ ] `sleep.reminder`
  1. `sleep.reminder#1` Напоминание в момент «действующая цель подъёма + задержка».
  2. `sleep.reminder#2` Напоминание едет вместе с дрейфующей целью.
  3. `sleep.reminder#3` Напоминание не приходит, если ночь за день уже есть.

- [ ] `sleep.skip`
  1. `sleep.skip#1` Пропуск диапазоном пишет Entry.skip на каждый день.
  2. `sleep.skip#2` Пропуск задним числом разрешён без ограничений.
  3. `sleep.skip#3` Счётчик показывает число пропусков за 30 дней.
  4. `sleep.skip#4` Смещение, отличающееся от предыдущей ночи на 120 минут и более, вызывает подсказку.
  5. `sleep.skip#5` Подсказка никогда не применяется сама.

- [ ] `sleep.suggest-goal`
  1. `sleep.suggest-goal#1` Подсказка требует не менее 10 ночей из 14.
  2. `sleep.suggest-goal#2` Подсказка требует медианного отклонения не менее 30 минут.
  3. `sleep.suggest-goal#3` Подсказка требует кругового разброса не более 45 минут.
  4. `sleep.suggest-goal#4` Подсказка никогда не применяется сама.

- [ ] `sleep.ui`
  1. `sleep.ui#1` Ячейка дня в списке показывает процент существующей числовой ячейкой.
  2. `sleep.ui#2` Блок прошлой ночи показывает три составляющие с баллами.
  3. `sleep.ui#3` Лента ночей: дни слева направо, время сверху вниз.
  4. `sleep.ui#4` Пропуски показаны штриховкой, ночи ниже половины — предупреждающим цветом.
  5. `sleep.ui#5` При отсутствии данных и при отказе в доступе экран остаётся рабочим.
  6. `sleep.ui#6` Редактор для типа «сон» показывает поля цели вместо полей числовой привычки.

- [ ] `sleep.export`
  1. `sleep.export#1` Привычка со сном экспортируется как числовая со значениями-процентами.
  2. `sleep.export#2` Ночи экспортируются отдельным файлом SleepSessions.csv.
```

- [ ] **Step 2: Написать падающий тест на второй реестр**

Создать `uhabits-flutter/tool/parity_coverage_test.dart`:

```dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('coverage tool reads the extension ledger', () async {
    final result = await Process.run(
      'dart',
      ['tool/parity_coverage.dart', '--uncited'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: 'sleep.habit-type#1');
    expect(
      result.stdout.toString(),
      contains('sleep.scoring#7'),
      reason: 'sleep.habit-type#1',
    );
  });
}
```

- [ ] **Step 3: Прогнать тест и убедиться, что он падает**

Run: `cd uhabits-flutter && dart test tool/parity_coverage_test.dart`
Expected: FAIL — вывод не содержит `sleep.scoring#7`, потому что инструмент читает только `docs/parity/FEATURES.md`.

- [ ] **Step 4: Научить инструмент читать два реестра**

В `tool/parity_coverage.dart` заменить чтение единственного файла на список. Сейчас там:

```dart
  final ledgerFile = File('$repoRoot/docs/parity/FEATURES.md');
  if (!ledgerFile.existsSync()) {
    stderr.writeln('Parity ledger not found at ${ledgerFile.path}');
    exit(1);
  }
```

Заменить на:

```dart
  final ledgerFiles = <File>[
    File('$repoRoot/docs/parity/FEATURES.md'),
    File('$repoRoot/docs/extensions/SLEEP.md'),
  ];
  for (final f in ledgerFiles) {
    if (!f.existsSync()) {
      stderr.writeln('Ledger not found at ${f.path}');
      exit(1);
    }
  }
```

Цикл `for (final line in ledgerFile.readAsLinesSync())` обернуть внешним циклом по `ledgerFiles`. Разбор строк не меняется: форматы идентичны, а префикс `sleep.` гарантирует, что ключи не столкнутся.

- [ ] **Step 5: Прогнать тест и убедиться, что он проходит**

Run: `cd uhabits-flutter && dart test tool/parity_coverage_test.dart`
Expected: PASS

- [ ] **Step 6: Убедиться, что паритетный реестр не пострадал**

Run: `cd uhabits-flutter && dart tool/parity_coverage.dart --verify && git diff --exit-code docs/parity/FEATURES.md`
Expected: проверка проходит, `FEATURES.md` не изменён.

- [ ] **Step 7: Коммит**

```bash
git add docs/extensions/SLEEP.md uhabits-flutter/tool/parity_coverage.dart uhabits-flutter/tool/parity_coverage_test.dart
git commit -m "feat(sleep): реестр расширений и второй источник для parity_coverage

Правила расширений живут отдельно от паритетных, чтобы не размывать
утверждение «совпадает с Kotlin». Префикс sleep. исключает столкновение
ключей.

sleep.habit-type#1"
```

---

### Task 2: Признак привычки со сном и границы значения записи

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/stored_value.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/stored_value_test.dart`

`habit_type.dart` **не меняется**. Третий элемент перечисления противоречил бы паритетному правилу `models.habit-type-enums#1` («ровно два элемента»), закрытому тестами: пришлось бы переписать паритетные тесты так, чтобы они утверждали не то, что написано в реестре. Привычка со сном — числовая привычка, у которой есть цель сна.

**Interfaces:**
- Consumes: ничего
- Produces: `int storedValueOf(double score)`, `maxStoredValue`, `minStoredValue`, `sleepHabitType`

- [ ] **Step 1: Написать падающие тесты**

Создать `packages/uhabits_core/test/sleep/stored_value_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';

void main() {
  test('sleep is the third habit type', () {
    expect(HabitType.sleep.value, 2, reason: 'sleep.habit-type#1');
    expect(HabitType.sleep.csvName, 'SLEEP', reason: 'sleep.habit-type#1');
    expect(HabitType.fromInt(2), HabitType.sleep, reason: 'sleep.habit-type#1');
  });

  test('score is stored as percent times 1000', () {
    expect(storedValueOf(0.87), 87000, reason: 'sleep.habit-type#3');
    expect(storedValueOf(1.0), 100000, reason: 'sleep.habit-type#3');
  });

  test('reserved values 1..3 collapse to zero', () {
    // 0.003% попадает ровно в Entry.skip и молча превратил бы день в пропуск.
    expect(storedValueOf(0.00003), 0, reason: 'sleep.stored-value#1');
    expect(storedValueOf(0.00002), 0, reason: 'sleep.stored-value#1');
    expect(storedValueOf(0.00001), 0, reason: 'sleep.stored-value#1');
    // Первое допустимое ненулевое значение.
    expect(storedValueOf(0.00004), 4, reason: 'sleep.stored-value#1');
  });

  test('values are clamped to the valid range', () {
    expect(storedValueOf(1.5), 100000, reason: 'sleep.stored-value#2');
    expect(storedValueOf(0.0), 0, reason: 'sleep.stored-value#3');
    expect(storedValueOf(-0.1), 0, reason: 'sleep.stored-value#3');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/stored_value_test.dart`
Expected: FAIL — `HabitType.sleep` и `stored_value.dart` не существуют.

- [ ] **Step 3: Добавить третий тип**

В `lib/src/models/habit_type.dart`:

```dart
enum HabitType {
  yesNo(0, 'YES_NO'),
  numerical(1, 'NUMERICAL'),
  sleep(2, 'SLEEP');
```

и в `fromInt` добавить ветку:

```dart
      case 2:
        return HabitType.sleep;
```

- [ ] **Step 4: Реализовать перевод значения**

Создать `lib/src/sleep/stored_value.dart`:

```dart
/// Верхняя граница значения записи дня: 100% × 1000.
const int maxStoredValue = 100000;

/// Наименьшее допустимое ненулевое значение.
///
/// Значения 1, 2 и 3 зарезервированы под Entry.yesAuto, Entry.yesManual и
/// Entry.skip. Ночь, набравшая 0.003%, попала бы ровно в Entry.skip и
/// молча превратилась бы в пропуск, подняв оценку вместо того, чтобы её
/// обвалить.
const int minStoredValue = 4;

/// Переводит долю выполнения 0…1 в значение записи дня.
int storedValueOf(double score) {
  if (!score.isFinite || score <= 0) return 0;
  final int value = (score * maxStoredValue).round();
  if (value <= 0) return 0;
  if (value < minStoredValue) return 0;
  if (value > maxStoredValue) return maxStoredValue;
  return value;
}
```

- [ ] **Step 5: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/stored_value_test.dart`
Expected: PASS

- [ ] **Step 6: Прогнать весь набор ядра**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test`
Expected: PASS. Особое внимание тестам, перебирающим `HabitType.values` — третий элемент мог сломать исчерпывающие `switch`. Если анализатор ругается на неисчерпывающий `switch` в существующем коде, добавить ветку `sleep`, ведущую себя как `numerical`, и **не** менять поведение первых двух типов.

- [ ] **Step 7: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/models/habit_type.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/sleep/stored_value.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/stored_value_test.dart
git commit -m "feat(sleep): третий тип привычки и границы значения записи

Значения 1..3 зарезервированы под служебные; расчёт, попавший в этот
диапазон, приводится к нулю, иначе плохая ночь стала бы пропуском.

sleep.habit-type#1 sleep.habit-type#3 sleep.stored-value#1
sleep.stored-value#2 sleep.stored-value#3"
```

---

### Task 3: Конфигурация цели

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_goal.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_goal_test.dart`

**Interfaces:**
- Consumes: ничего
- Produces: `SleepGoal` с полями `bedMinutes`, `wakeMinutes`, `minSleepMinutes`, `weightSleep`, `weightBed`, `weightWake`, `halfCreditTimeMinutes`, `halfCreditSleepMinutes`, `homeUtcOffsetMinutes`, `adaptationMinutesPerDay`, `mergeGapMinutes`, `promptAfterWakeMinutes`; геттеры `weightSum`, `isConfigured`, `normalizedWeights`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';

void main() {
  const goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

  test('defaults match the spec', () {
    expect(goal.minSleepMinutes, 450, reason: 'sleep.goal#1');
    expect(goal.weightSleep, 0.4, reason: 'sleep.goal#1');
    expect(goal.weightBed, 0.3, reason: 'sleep.goal#1');
    expect(goal.weightWake, 0.3, reason: 'sleep.goal#1');
    expect(goal.halfCreditTimeMinutes, 90, reason: 'sleep.goal#1');
    expect(goal.halfCreditSleepMinutes, 60, reason: 'sleep.goal#1');
    expect(goal.adaptationMinutesPerDay, 60, reason: 'sleep.goal#1');
    expect(goal.mergeGapMinutes, 60, reason: 'sleep.goal#1');
    expect(goal.promptAfterWakeMinutes, 60, reason: 'sleep.goal#1');
  });

  test('weights are normalized to sum one', () {
    const skewed = SleepGoal(
      bedMinutes: 1380,
      wakeMinutes: 420,
      weightSleep: 2,
      weightBed: 1,
      weightWake: 1,
    );
    final w = skewed.normalizedWeights;
    expect(w.sleep, closeTo(0.5, 1e-9), reason: 'sleep.goal#2');
    expect(w.bed, closeTo(0.25, 1e-9), reason: 'sleep.goal#2');
    expect(w.wake, closeTo(0.25, 1e-9), reason: 'sleep.goal#2');
  });

  test('zero weights mean the goal is not configured', () {
    const empty = SleepGoal(
      bedMinutes: 1380,
      wakeMinutes: 420,
      weightSleep: 0,
      weightBed: 0,
      weightWake: 0,
    );
    expect(empty.isConfigured, isFalse, reason: 'sleep.goal#3');
    expect(goal.isConfigured, isTrue, reason: 'sleep.goal#3');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_goal_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать**

```dart
/// Нормированные веса трёх составляющих. Сумма равна 1.
class SleepWeights {
  const SleepWeights(this.sleep, this.bed, this.wake);
  final double sleep;
  final double bed;
  final double wake;
}

/// Конфигурация цели по сну. Объект-значение, ничего не вычисляет сам.
class SleepGoal {
  const SleepGoal({
    required this.bedMinutes,
    required this.wakeMinutes,
    this.minSleepMinutes = 450,
    this.weightSleep = 0.4,
    this.weightBed = 0.3,
    this.weightWake = 0.3,
    this.halfCreditTimeMinutes = 90,
    this.halfCreditSleepMinutes = 60,
    this.homeUtcOffsetMinutes = 0,
    this.adaptationMinutesPerDay = 60,
    this.mergeGapMinutes = 60,
    this.promptAfterWakeMinutes = 60,
  });

  /// Минут от полуночи.
  final int bedMinutes;
  final int wakeMinutes;
  final int minSleepMinutes;

  final double weightSleep;
  final double weightBed;
  final double weightWake;

  final int halfCreditTimeMinutes;
  final int halfCreditSleepMinutes;

  final int homeUtcOffsetMinutes;
  final int adaptationMinutesPerDay;
  final int mergeGapMinutes;
  final int promptAfterWakeMinutes;

  double get weightSum => weightSleep + weightBed + weightWake;

  bool get isConfigured => weightSum > 0;

  SleepWeights get normalizedWeights {
    final sum = weightSum;
    if (sum <= 0) return const SleepWeights(0, 0, 0);
    return SleepWeights(weightSleep / sum, weightBed / sum, weightWake / sum);
  }
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_goal_test.dart`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_goal.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_goal_test.dart
git commit -m "feat(sleep): конфигурация цели

sleep.goal#1 sleep.goal#2 sleep.goal#3"
```

---

## Фаза 2 — модель оценки

### Task 4: Оценка ночи

Сердце фичи. Контрольные векторы из раздела 4.3 спецификации входят в тест как есть.

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_episode.dart`
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_scorer.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_scorer_test.dart`

**Interfaces:**
- Consumes: `SleepGoal` из Task 3, `storedValueOf` из Task 2
- Produces:
  - `SleepEpisode({required int bedStartMillis, required int wakeEndMillis, required int asleepMinutes, required int utcOffsetMinutes, bool derivedFromAsleep, String sourceId})`
  - `int circularDistance(int a, int b)`
  - `double componentScore(int deviationMinutes, int halfCreditMinutes)`
  - `SleepBreakdown scoreNight(SleepEpisode episode, SleepGoal goal, int effectiveOffsetMinutes)`
  - `SleepBreakdown` с полями `bedMinutes`, `wakeMinutes`, `asleepMinutes`, `devBed`, `devWake`, `devSleep`, `scoreBed`, `scoreWake`, `scoreSleep`, `total`, `storedValue`, `weakest`
  - `enum SleepComponent { sleep, bed, wake }`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_scorer.dart';

/// Цель: лечь 23:00, встать 07:00, спать не менее 7:30.
const goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

/// Собирает ночь из местных времён, чтобы тесты читались как спецификация.
/// [bedMinutes] может быть больше 1440 — это отход после полуночи.
SleepEpisode night(int bedMinutes, int wakeMinutes, int asleepMinutes) {
  const dayStartMillis = 1756080000000; // произвольная полночь UTC
  return SleepEpisode(
    bedStartMillis: dayStartMillis + bedMinutes * 60000,
    wakeEndMillis: dayStartMillis + (wakeMinutes + 1440) * 60000,
    asleepMinutes: asleepMinutes,
    utcOffsetMinutes: 0,
  );
}

void main() {
  group('circular distance', () {
    test('wraps around midnight', () {
      expect(circularDistance(1430, 10), 20, reason: 'sleep.scoring#1');
      expect(circularDistance(10, 1430), 20, reason: 'sleep.scoring#1');
      expect(circularDistance(420, 420), 0, reason: 'sleep.scoring#1');
      expect(circularDistance(0, 720), 720, reason: 'sleep.scoring#1');
    });
  });

  group('component score', () {
    test('is exactly one at zero deviation', () {
      expect(componentScore(0, 90), closeTo(1.0, 1e-12),
          reason: 'sleep.scoring#4');
      expect(componentScore(0, 60), closeTo(1.0, 1e-12),
          reason: 'sleep.scoring#4');
    });

    test('matches the curve for time components', () {
      const expected = <int, double>{
        0: 1.000, 15: 0.988, 30: 0.963, 45: 0.915, 60: 0.827,
        90: 0.506, 120: 0.184, 150: 0.048, 180: 0.011,
      };
      expected.forEach((deviation, value) {
        expect(componentScore(deviation, 90), closeTo(value, 0.0005),
            reason: 'sleep.scoring#3');
      });
    });

    test('matches the curve for the duration component', () {
      const expected = <int, double>{
        0: 1.000, 15: 0.950, 30: 0.858, 45: 0.713,
        60: 0.525, 90: 0.192, 120: 0.050,
      };
      expected.forEach((deviation, value) {
        expect(componentScore(deviation, 60), closeTo(value, 0.0005),
            reason: 'sleep.scoring#3');
      });
    });

    test('decreases monotonically', () {
      var previous = componentScore(0, 90);
      for (var d = 1; d <= 720; d++) {
        final current = componentScore(d, 90);
        expect(current, lessThan(previous), reason: 'sleep.scoring#3');
        previous = current;
      }
    });
  });

  group('night scoring', () {
    test('oversleeping is never penalised', () {
      final short = scoreNight(night(1380, 420, 450), goal, 0);
      final long = scoreNight(night(1380, 420, 600), goal, 0);
      expect(short.scoreSleep, closeTo(1.0, 1e-12), reason: 'sleep.scoring#2');
      expect(long.scoreSleep, closeTo(1.0, 1e-12), reason: 'sleep.scoring#2');
    });

    test('duration is actual sleep, not bed-to-wake span', () {
      // Лёг 23:00, встал 07:00 — восемь часов в постели, но спал пять.
      final result = scoreNight(night(1380, 420, 300), goal, 0);
      expect(result.devBed, 0, reason: 'sleep.scoring#6');
      expect(result.devWake, 0, reason: 'sleep.scoring#6');
      expect(result.devSleep, 150, reason: 'sleep.scoring#6');
      expect(result.scoreBed, closeTo(1.0, 1e-12), reason: 'sleep.scoring#6');
      expect(result.total, lessThan(0.5), reason: 'sleep.scoring#6');
    });

    test('control vectors from the spec', () {
      // Каждая строка: отход, подъём, фактический сон, ожидаемый процент.
      const vectors = <List<int>>[
        [1390, 425, 475, 100], // 23:10 / 07:05 / 7:55
        [1421, 432, 408, 87],  // 23:41 / 07:12 / 6:48
        [1440, 480, 480, 89],  // 00:00 / 08:00 / 8:00
        [1500, 480, 420, 53],  // 01:00 / 08:00 / 7:00
        [1560, 540, 420, 15],  // 02:00 / 09:00 / 7:00
      ];
      for (final v in vectors) {
        final result = scoreNight(night(v[0], v[1], v[2]), goal, 0);
        expect((result.total * 100).round(), v[3],
            reason: 'sleep.scoring#7');
      }
    });

    test('combination is geometric, not arithmetic', () {
      // Ночь из последнего вектора: арифметическое дало бы 40%.
      final result = scoreNight(night(1560, 540, 420), goal, 0);
      final weights = goal.normalizedWeights;
      final arithmetic = weights.sleep * result.scoreSleep +
          weights.bed * result.scoreBed +
          weights.wake * result.scoreWake;
      expect(arithmetic, greaterThan(0.35), reason: 'sleep.scoring#5');
      expect(result.total, lessThan(0.20), reason: 'sleep.scoring#5');
    });

    test('breakdown names the weakest component', () {
      final result = scoreNight(night(1380, 420, 300), goal, 0);
      expect(result.weakest, SleepComponent.sleep, reason: 'sleep.scoring#8');
      final late = scoreNight(night(1560, 420, 480), goal, 0);
      expect(late.weakest, SleepComponent.bed, reason: 'sleep.scoring#8');
    });

    test('an unconfigured goal yields no value', () {
      const empty = SleepGoal(
        bedMinutes: 1380, wakeMinutes: 420,
        weightSleep: 0, weightBed: 0, weightWake: 0,
      );
      expect(scoreNight(night(1380, 420, 480), empty, 0), isNull,
          reason: 'sleep.goal#3');
    });
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_scorer_test.dart`
Expected: FAIL — файлы не существуют.

- [ ] **Step 3: Реализовать объект-значение ночи**

Создать `lib/src/sleep/sleep_episode.dart`:

```dart
/// Одна ночь: границы «в постели» и фактический сон внутри них.
class SleepEpisode {
  const SleepEpisode({
    required this.bedStartMillis,
    required this.wakeEndMillis,
    required this.asleepMinutes,
    required this.utcOffsetMinutes,
    this.derivedFromAsleep = false,
    this.sourceId = '',
  });

  /// Момент отхода ко сну, UTC, миллисекунды.
  final int bedStartMillis;

  /// Момент пробуждения, UTC, миллисекунды.
  final int wakeEndMillis;

  /// Фактический сон внутри эпизода. Не равен разности границ:
  /// можно лечь в 23:00, уснуть в 02:00 и встать в 07:00.
  final int asleepMinutes;

  /// Смещение от UTC в минутах, действовавшее в момент пробуждения.
  final int utcOffsetMinutes;

  /// Границ «в постели» в данных не было, они взяты из отрезков сна.
  final bool derivedFromAsleep;

  /// Bundle id источника в Health; пусто для ручного ввода.
  final String sourceId;
}

/// Минуты от полуночи для момента в заданном смещении.
int localMinutesOf(int millis, int utcOffsetMinutes) {
  final total = (millis ~/ 60000) + utcOffsetMinutes;
  final remainder = total % 1440;
  return remainder < 0 ? remainder + 1440 : remainder;
}
```

- [ ] **Step 4: Реализовать оценку**

Создать `lib/src/sleep/sleep_scorer.dart`:

```dart
import 'dart:math' as math;

import 'sleep_episode.dart';
import 'sleep_goal.dart';
import 'stored_value.dart';

/// Крутизна логистической кривой, 1/мин. Константа: форма кривой —
/// часть модели, а не вкусовая настройка.
const double steepness = 0.05;

enum SleepComponent { sleep, bed, wake }

/// Круговое расстояние между двумя моментами суток в минутах.
///
/// 23:50 и 00:10 отстоят на 20 минут, а не на 1420.
int circularDistance(int a, int b) {
  final d = (a - b).abs() % 1440;
  return math.min(d, 1440 - d);
}

/// Балл составляющей: 1 при нулевом отклонении, половина при [halfCreditMinutes].
///
/// Кривая намеренно S-образна: малые отклонения почти бесплатны, средние
/// стоят резко дорого, большие неразличимы между собой.
double componentScore(int deviationMinutes, int halfCreditMinutes) {
  final m = halfCreditMinutes.toDouble();
  final d = deviationMinutes.toDouble();
  return (1 + math.exp(-steepness * m)) / (1 + math.exp(steepness * (d - m)));
}

/// Разбор ночи: три составляющие, их баллы и итог.
class SleepBreakdown {
  const SleepBreakdown({
    required this.bedMinutes,
    required this.wakeMinutes,
    required this.asleepMinutes,
    required this.devBed,
    required this.devWake,
    required this.devSleep,
    required this.scoreBed,
    required this.scoreWake,
    required this.scoreSleep,
    required this.total,
  });

  final int bedMinutes;
  final int wakeMinutes;
  final int asleepMinutes;

  final int devBed;
  final int devWake;
  final int devSleep;

  final double scoreBed;
  final double scoreWake;
  final double scoreSleep;

  /// Итоговая доля выполнения, 0…1.
  final double total;

  int get storedValue => storedValueOf(total);

  /// Составляющая, внёсшая наибольшую потерю.
  SleepComponent get weakest {
    if (scoreSleep <= scoreBed && scoreSleep <= scoreWake) {
      return SleepComponent.sleep;
    }
    return scoreBed <= scoreWake ? SleepComponent.bed : SleepComponent.wake;
  }
}

/// Оценивает ночь относительно цели в действующем часовом поясе.
///
/// Возвращает null, если цель не настроена.
SleepBreakdown? scoreNight(
  SleepEpisode episode,
  SleepGoal goal,
  int effectiveOffsetMinutes,
) {
  if (!goal.isConfigured) return null;

  final bedMinutes = localMinutesOf(episode.bedStartMillis, effectiveOffsetMinutes);
  final wakeMinutes = localMinutesOf(episode.wakeEndMillis, effectiveOffsetMinutes);

  final devBed = circularDistance(bedMinutes, goal.bedMinutes);
  final devWake = circularDistance(wakeMinutes, goal.wakeMinutes);
  final devSleep = math.max(0, goal.minSleepMinutes - episode.asleepMinutes);

  final scoreBed = componentScore(devBed, goal.halfCreditTimeMinutes);
  final scoreWake = componentScore(devWake, goal.halfCreditTimeMinutes);
  final scoreSleep = componentScore(devSleep, goal.halfCreditSleepMinutes);

  final w = goal.normalizedWeights;
  final total = math.exp(
    w.sleep * math.log(scoreSleep) +
        w.bed * math.log(scoreBed) +
        w.wake * math.log(scoreWake),
  );

  return SleepBreakdown(
    bedMinutes: bedMinutes,
    wakeMinutes: wakeMinutes,
    asleepMinutes: episode.asleepMinutes,
    devBed: devBed,
    devWake: devWake,
    devSleep: devSleep,
    scoreBed: scoreBed,
    scoreWake: scoreWake,
    scoreSleep: scoreSleep,
    total: total,
  );
}
```

- [ ] **Step 5: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_scorer_test.dart`
Expected: PASS

- [ ] **Step 6: Доказать, что контрольные векторы нагружены**

Мутационная проверка: во временной копии заменить `math.exp(...)` на арифметическое среднее `w.sleep * scoreSleep + w.bed * scoreBed + w.wake * scoreWake` и прогнать тест.

Run: тест обязан упасть на векторах `[1500, 480, 420, 53]` и `[1560, 540, 420, 15]`.
Если он проходит — векторы не различают две модели свёртки, и тест бесполезен. Вернуть исходный код после проверки.

- [ ] **Step 7: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_episode.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_scorer.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_scorer_test.dart
git commit -m "feat(sleep): оценка ночи

Логистические баллы трёх составляющих, свёрнутые взвешенным
геометрическим средним. Длительность берётся как фактический сон,
а не как разность границ.

sleep.scoring#1..#8"
```

---

### Task 5: Дрейф часового пояса

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/timezone_drift.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/timezone_drift_test.dart`

**Interfaces:**
- Consumes: ничего
- Produces: `Map<int, int> effectiveOffsets({required int firstDay, required int lastDay, required Map<int, int> observedByDay, required int homeOffsetMinutes, required int ratePerDayMinutes})` — ключ это `daysSince2000`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/timezone_drift.dart';

void main() {
  test('a settled home timezone never drifts', () {
    final offsets = effectiveOffsets(
      firstDay: 100,
      lastDay: 105,
      observedByDay: {for (var d = 100; d <= 105; d++) d: 180},
      homeOffsetMinutes: 180,
      ratePerDayMinutes: 60,
    );
    for (var d = 100; d <= 105; d++) {
      expect(offsets[d], 180, reason: 'sleep.timezone#1');
    }
  });

  test('the first day is pinned to the home offset', () {
    final offsets = effectiveOffsets(
      firstDay: 100,
      lastDay: 101,
      observedByDay: {100: -240, 101: -240},
      homeOffsetMinutes: 180,
      ratePerDayMinutes: 60,
    );
    expect(offsets[100], 180, reason: 'sleep.timezone#2');
  });

  test('a seven hour flight takes seven days, one hour at a time', () {
    // День 100 — последняя ночь дома, день 101 — ночь прилёта.
    final observed = <int, int>{100: 180};
    for (var d = 101; d <= 110; d++) {
      observed[d] = -240;
    }
    final offsets = effectiveOffsets(
      firstDay: 100,
      lastDay: 110,
      observedByDay: observed,
      homeOffsetMinutes: 180,
      ratePerDayMinutes: 60,
    );
    // В ночь прилёта цель ещё не сдвинулась: шаг задаёт предыдущий день.
    expect(offsets[101], 180, reason: 'sleep.timezone#3');
    const expected = <int, int>{
      101: 180, 102: 120, 103: 60, 104: 0,
      105: -60, 106: -120, 107: -180, 108: -240,
    };
    expected.forEach((day, offset) {
      expect(offsets[day], offset, reason: 'sleep.timezone#6');
    });
    // Догнав, дальше стоит на месте.
    expect(offsets[109], -240, reason: 'sleep.timezone#6');
    expect(offsets[110], -240, reason: 'sleep.timezone#6');
  });

  test('the step is bounded in both directions', () {
    final east = effectiveOffsets(
      firstDay: 0, lastDay: 2,
      observedByDay: {0: 0, 1: 600, 2: 600},
      homeOffsetMinutes: 0, ratePerDayMinutes: 60,
    );
    expect(east[1], 0, reason: 'sleep.timezone#4');
    expect(east[2], 60, reason: 'sleep.timezone#4');

    final west = effectiveOffsets(
      firstDay: 0, lastDay: 2,
      observedByDay: {0: 0, 1: -600, 2: -600},
      homeOffsetMinutes: 0, ratePerDayMinutes: 60,
    );
    expect(west[2], -60, reason: 'sleep.timezone#4');
  });

  test('a day without a night inherits the nearest earlier observation', () {
    final offsets = effectiveOffsets(
      firstDay: 0, lastDay: 4,
      observedByDay: {0: 0, 1: 180}, // дни 2..4 без ночей
      homeOffsetMinutes: 0, ratePerDayMinutes: 60,
    );
    expect(offsets[2], 0, reason: 'sleep.timezone#5');
    expect(offsets[3], 60, reason: 'sleep.timezone#5');
    expect(offsets[4], 120, reason: 'sleep.timezone#5');
  });

  test('the result is a pure function of its inputs', () {
    Map<int, int> run() => effectiveOffsets(
          firstDay: 0, lastDay: 30,
          observedByDay: {0: 0, 5: 300, 12: -120, 20: 60},
          homeOffsetMinutes: 0, ratePerDayMinutes: 60,
        );
    expect(run(), equals(run()), reason: 'sleep.timezone#1');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/timezone_drift_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать**

```dart
import 'dart:math' as math;

/// Действующий часовой пояс цели по дням.
///
/// Не хранимое состояние, а чистая функция от истории наблюдённых смещений:
/// иначе результат зависел бы от того, когда пользователь открыл приложение,
/// и история перестала бы пересчитываться.
///
/// Шаг задаётся наблюдением предыдущего дня, а не текущего: в ночь прилёта
/// цель ещё не двигается, потому что организм за сутки не перестраивается.
Map<int, int> effectiveOffsets({
  required int firstDay,
  required int lastDay,
  required Map<int, int> observedByDay,
  required int homeOffsetMinutes,
  required int ratePerDayMinutes,
}) {
  final result = <int, int>{};
  if (lastDay < firstDay) return result;

  final rate = ratePerDayMinutes.abs();
  var current = homeOffsetMinutes;
  var lastObserved = observedByDay[firstDay] ?? homeOffsetMinutes;
  result[firstDay] = current;

  for (var day = firstDay + 1; day <= lastDay; day++) {
    // Шаг определяется тем, что наблюдалось накануне.
    final delta = (lastObserved - current).clamp(-rate, rate);
    current += delta;
    result[day] = current;
    lastObserved = observedByDay[day] ?? lastObserved;
  }
  return result;
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/timezone_drift_test.dart`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/timezone_drift.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/timezone_drift_test.dart
git commit -m "feat(sleep): дрейф часового пояса цели

Чистая свёртка по истории смещений: цель догоняет местное время со
скоростью час в сутки, начиная со дня после смены пояса.

sleep.timezone#1..#6"
```

---

### Task 6: Склейка отрезков в ночь

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_segment.dart`
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_episode_merger.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_episode_merger_test.dart`

**Interfaces:**
- Consumes: `SleepEpisode` из Task 4
- Produces:
  - `enum SleepSegmentKind { inBed, asleepCore, asleepDeep, asleepRem, asleepUnspecified, awake }` с геттером `bool get isAsleep`
  - `SleepSegment({required int startMillis, required int endMillis, required SleepSegmentKind kind, required String sourceId})` с геттером `int get durationMinutes`
  - `SleepEpisode? mergeSegments(List<SleepSegment> segments, {required int mergeGapMinutes, required int utcOffsetMinutes})`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode_merger.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';

const int midnight = 1756080000000;

SleepSegment seg(
  int startMinutes,
  int endMinutes,
  SleepSegmentKind kind, {
  String source = 'watch',
}) =>
    SleepSegment(
      startMillis: midnight + startMinutes * 60000,
      endMillis: midnight + endMinutes * 60000,
      kind: kind,
      sourceId: source,
    );

void main() {
  test('the source with the most sleep wins', () {
    final episode = mergeSegments(
      [
        seg(0, 60, SleepSegmentKind.asleepCore, source: 'phone'),
        seg(0, 420, SleepSegmentKind.asleepCore, source: 'watch'),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.sourceId, 'watch', reason: 'sleep.merge#1');
    expect(episode.asleepMinutes, 420, reason: 'sleep.merge#1');
  });

  test('ties are broken deterministically by source id', () {
    final episode = mergeSegments(
      [
        seg(0, 60, SleepSegmentKind.asleepCore, source: 'bbb'),
        seg(0, 60, SleepSegmentKind.asleepCore, source: 'aaa'),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.sourceId, 'aaa', reason: 'sleep.merge#2');
  });

  test('a gap at the threshold merges, one minute more splits', () {
    final merged = mergeSegments(
      [
        seg(0, 120, SleepSegmentKind.asleepCore),
        seg(180, 420, SleepSegmentKind.asleepCore), // разрыв ровно 60
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(merged!.asleepMinutes, 360, reason: 'sleep.merge#3');

    final split = mergeSegments(
      [
        seg(0, 120, SleepSegmentKind.asleepCore),
        seg(181, 420, SleepSegmentKind.asleepCore), // разрыв 61
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(split!.asleepMinutes, 239, reason: 'sleep.merge#3');
  });

  test('the chain with the most sleep wins, not the widest one', () {
    // Цепочка A: два коротких отрезка с широким размахом.
    // Цепочка B: один длинный отрезок.
    final episode = mergeSegments(
      [
        seg(0, 30, SleepSegmentKind.asleepCore),
        seg(80, 110, SleepSegmentKind.asleepCore),
        seg(400, 700, SleepSegmentKind.asleepCore),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.asleepMinutes, 300, reason: 'sleep.merge#4');
  });

  test('asleep minutes sum the segments, not the span', () {
    final episode = mergeSegments(
      [
        seg(0, 120, SleepSegmentKind.asleepCore),
        seg(150, 300, SleepSegmentKind.asleepDeep),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    // Размах 300 минут, фактический сон 270.
    expect(episode!.asleepMinutes, 270, reason: 'sleep.merge#5');
  });

  test('awake segments never count as sleep', () {
    final episode = mergeSegments(
      [
        seg(0, 120, SleepSegmentKind.asleepCore),
        seg(120, 150, SleepSegmentKind.awake),
        seg(150, 300, SleepSegmentKind.asleepCore),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.asleepMinutes, 270, reason: 'sleep.merge#5');
  });

  test('in-bed boundaries win over the asleep chain', () {
    // Лёг в 23:00, уснул в 02:00, встал в 07:00.
    final episode = mergeSegments(
      [
        seg(0, 480, SleepSegmentKind.inBed),
        seg(180, 480, SleepSegmentKind.asleepCore),
      ],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.bedStartMillis, midnight, reason: 'sleep.merge#6');
    expect(episode.wakeEndMillis, midnight + 480 * 60000,
        reason: 'sleep.merge#6');
    expect(episode.asleepMinutes, 300, reason: 'sleep.merge#6');
    expect(episode.derivedFromAsleep, isFalse, reason: 'sleep.merge#6');
  });

  test('without in-bed data the chain provides the boundaries', () {
    final episode = mergeSegments(
      [seg(180, 480, SleepSegmentKind.asleepCore)],
      mergeGapMinutes: 60,
      utcOffsetMinutes: 0,
    );
    expect(episode!.bedStartMillis, midnight + 180 * 60000,
        reason: 'sleep.merge#6');
    expect(episode.derivedFromAsleep, isTrue, reason: 'sleep.merge#6');
  });

  test('no sleep segments means no episode', () {
    expect(
      mergeSegments([seg(0, 480, SleepSegmentKind.inBed)],
          mergeGapMinutes: 60, utcOffsetMinutes: 0),
      isNull,
      reason: 'sleep.merge#4',
    );
    expect(
      mergeSegments([], mergeGapMinutes: 60, utcOffsetMinutes: 0),
      isNull,
      reason: 'sleep.merge#4',
    );
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_episode_merger_test.dart`
Expected: FAIL — файлы не существуют.

- [ ] **Step 3: Реализовать отрезок**

Создать `lib/src/sleep/sleep_segment.dart`:

```dart
/// Вид отрезка, как его отдаёт HealthKit.
enum SleepSegmentKind {
  inBed,
  asleepCore,
  asleepDeep,
  asleepRem,
  asleepUnspecified,
  awake;

  bool get isAsleep =>
      this == asleepCore ||
      this == asleepDeep ||
      this == asleepRem ||
      this == asleepUnspecified;
}

/// Сырой отрезок из источника данных. Логики не несёт.
class SleepSegment {
  const SleepSegment({
    required this.startMillis,
    required this.endMillis,
    required this.kind,
    required this.sourceId,
  });

  final int startMillis;
  final int endMillis;
  final SleepSegmentKind kind;

  /// Bundle id приложения-источника в Health.
  final String sourceId;

  int get durationMinutes => (endMillis - startMillis) ~/ 60000;
}
```

- [ ] **Step 4: Реализовать склейку**

Создать `lib/src/sleep/sleep_episode_merger.dart`:

```dart
import 'sleep_episode.dart';
import 'sleep_segment.dart';

/// Сводит сырые отрезки за одну ночь к единственному эпизоду.
///
/// Возвращает null, если отрезков сна нет.
SleepEpisode? mergeSegments(
  List<SleepSegment> segments, {
  required int mergeGapMinutes,
  required int utcOffsetMinutes,
}) {
  if (segments.isEmpty) return null;

  final group = _bestSource(segments);
  if (group == null) return null;

  final asleep = group.segments.where((s) => s.kind.isAsleep).toList()
    ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
  if (asleep.isEmpty) return null;

  final chain = _bestChain(asleep, mergeGapMinutes);
  final asleepMinutes =
      chain.fold<int>(0, (sum, s) => sum + s.durationMinutes);
  final chainStart = chain.first.startMillis;
  final chainEnd =
      chain.fold<int>(chain.first.endMillis, (m, s) => s.endMillis > m ? s.endMillis : m);

  // Границы «в постели» — только те отрезки, что пересекают цепочку.
  final inBed = group.segments
      .where((s) => s.kind == SleepSegmentKind.inBed)
      .where((s) => s.endMillis > chainStart && s.startMillis < chainEnd)
      .toList();

  final int bedStart;
  final int wakeEnd;
  final bool derived;
  if (inBed.isEmpty) {
    bedStart = chainStart;
    wakeEnd = chainEnd;
    derived = true;
  } else {
    bedStart = inBed.map((s) => s.startMillis).reduce((a, b) => a < b ? a : b);
    wakeEnd = inBed.map((s) => s.endMillis).reduce((a, b) => a > b ? a : b);
    derived = false;
  }

  return SleepEpisode(
    bedStartMillis: bedStart,
    wakeEndMillis: wakeEnd,
    asleepMinutes: asleepMinutes,
    utcOffsetMinutes: utcOffsetMinutes,
    derivedFromAsleep: derived,
    sourceId: group.sourceId,
  );
}

class _SourceGroup {
  _SourceGroup(this.sourceId, this.segments);
  final String sourceId;
  final List<SleepSegment> segments;
}

/// Одну ночь нередко пишут и часы, и стороннее приложение. Побеждает
/// источник с наибольшей суммой сна; при равенстве — лексикографически
/// меньший bundle id, чтобы результат не зависел от порядка выборки.
_SourceGroup? _bestSource(List<SleepSegment> segments) {
  final bySource = <String, List<SleepSegment>>{};
  for (final s in segments) {
    (bySource[s.sourceId] ??= <SleepSegment>[]).add(s);
  }
  _SourceGroup? best;
  var bestTotal = -1;
  final keys = bySource.keys.toList()..sort();
  for (final key in keys) {
    final list = bySource[key]!;
    final total = list
        .where((s) => s.kind.isAsleep)
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
    if (total > bestTotal) {
      bestTotal = total;
      best = _SourceGroup(key, list);
    }
  }
  return best;
}

/// Разбивает отрезки сна на цепочки по порогу склейки и возвращает
/// цепочку с наибольшей суммой сна — она и есть главный эпизод.
/// Дневной сон остаётся отдельной цепочкой и проигрывает ночной.
List<SleepSegment> _bestChain(List<SleepSegment> asleep, int mergeGapMinutes) {
  final chains = <List<SleepSegment>>[
    <SleepSegment>[asleep.first]
  ];
  var chainEnd = asleep.first.endMillis;
  for (final s in asleep.skip(1)) {
    final gapMinutes = (s.startMillis - chainEnd) ~/ 60000;
    if (gapMinutes <= mergeGapMinutes) {
      chains.last.add(s);
    } else {
      chains.add(<SleepSegment>[s]);
    }
    if (s.endMillis > chainEnd) chainEnd = s.endMillis;
  }
  var best = chains.first;
  var bestTotal = -1;
  for (final chain in chains) {
    final total = chain.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    if (total > bestTotal) {
      bestTotal = total;
      best = chain;
    }
  }
  return best;
}
```

- [ ] **Step 5: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_episode_merger_test.dart`
Expected: PASS

- [ ] **Step 6: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_segment.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_episode_merger.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_episode_merger_test.dart
git commit -m "feat(sleep): склейка отрезков в эпизод

Дедупликация источников, склейка через короткие пробуждения, выбор
главной цепочки по сумме сна, а не по размаху.

sleep.merge#1..#6"
```

---

### Task 7: Стабильность

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_stability.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_stability_test.dart`

**Interfaces:**
- Consumes: `SleepEpisode` из Task 4
- Produces: `SleepStability? computeStability(List<SleepEpisode> episodes, {required int minNights})` с полями `bedSpreadMinutes`, `wakeSpreadMinutes`, `meanAsleepMinutes`, `nightCount`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_stability.dart';

const int midnight = 1756080000000;

SleepEpisode night(int bedMinutes, int wakeMinutes, int asleepMinutes) =>
    SleepEpisode(
      bedStartMillis: midnight + bedMinutes * 60000,
      wakeEndMillis: midnight + wakeMinutes * 60000,
      asleepMinutes: asleepMinutes,
      utcOffsetMinutes: 0,
    );

void main() {
  test('times around midnight give a small spread, not a full day', () {
    // 23:50, 00:10, 23:55, 00:05 — разброс порядка десяти минут.
    final result = computeStability(
      [
        night(1430, 420, 450),
        night(1450, 430, 450),
        night(1435, 425, 450),
        night(1445, 435, 450),
      ],
      minNights: 4,
    );
    expect(result!.bedSpreadMinutes, lessThan(30), reason: 'sleep.stability#1');
  });

  test('identical nights have zero spread', () {
    final result = computeStability(
      List.filled(5, night(1380, 420, 480)),
      minNights: 4,
    );
    expect(result!.bedSpreadMinutes, closeTo(0, 0.5),
        reason: 'sleep.stability#1');
    expect(result.wakeSpreadMinutes, closeTo(0, 0.5),
        reason: 'sleep.stability#1');
    expect(result.meanAsleepMinutes, closeTo(480, 0.5),
        reason: 'sleep.stability#1');
  });

  test('too few nights yield nothing', () {
    expect(
      computeStability([night(1380, 420, 480)], minNights: 4),
      isNull,
      reason: 'sleep.stability#3',
    );
    expect(
      computeStability(const [], minNights: 4),
      isNull,
      reason: 'sleep.stability#3',
    );
  });

  test('a scattered schedule gives a large spread', () {
    final result = computeStability(
      [
        night(1320, 400, 450), // 22:00
        night(1440, 480, 450), // 00:00
        night(1560, 540, 450), // 02:00
        night(1380, 420, 450), // 23:00
      ],
      minNights: 4,
    );
    expect(result!.bedSpreadMinutes, greaterThan(60),
        reason: 'sleep.stability#1');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_stability_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать**

```dart
import 'dart:math' as math;

import 'sleep_episode.dart';

/// Разброс времён и средняя длительность за окно.
class SleepStability {
  const SleepStability({
    required this.bedSpreadMinutes,
    required this.wakeSpreadMinutes,
    required this.meanAsleepMinutes,
    required this.nightCount,
  });

  final double bedSpreadMinutes;
  final double wakeSpreadMinutes;
  final double meanAsleepMinutes;
  final int nightCount;
}

/// Круговое стандартное отклонение моментов суток в минутах.
///
/// Обычное отклонение здесь непригодно: 23:50 и 00:10 отстоят на 20 минут,
/// а не на 1420, и линейная формула объявила бы стабильный режим хаосом.
double circularSpread(List<int> minutes) {
  if (minutes.isEmpty) return 0;
  var sumSin = 0.0;
  var sumCos = 0.0;
  for (final m in minutes) {
    final theta = 2 * math.pi * m / 1440;
    sumSin += math.sin(theta);
    sumCos += math.cos(theta);
  }
  final n = minutes.length;
  final r = math.sqrt(sumSin * sumSin + sumCos * sumCos) / n;
  if (r >= 1.0) return 0;
  if (r <= 0) return 1440 / 4; // полная неопределённость
  return 1440 / (2 * math.pi) * math.sqrt(-2 * math.log(r));
}

/// Считает стабильность по уже отфильтрованному списку ночей.
///
/// Отбор — забота вызывающего: пропуски и дни без данных сюда не попадают,
/// иначе один перелёт раздул бы разброс на две недели вперёд.
SleepStability? computeStability(
  List<SleepEpisode> episodes, {
  required int minNights,
}) {
  if (episodes.length < minNights) return null;

  final bed = <int>[];
  final wake = <int>[];
  var asleepTotal = 0;
  for (final e in episodes) {
    bed.add(localMinutesOf(e.bedStartMillis, e.utcOffsetMinutes));
    wake.add(localMinutesOf(e.wakeEndMillis, e.utcOffsetMinutes));
    asleepTotal += e.asleepMinutes;
  }

  return SleepStability(
    bedSpreadMinutes: circularSpread(bed),
    wakeSpreadMinutes: circularSpread(wake),
    meanAsleepMinutes: asleepTotal / episodes.length,
    nightCount: episodes.length,
  );
}
```

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_stability_test.dart`
Expected: PASS

- [ ] **Step 5: Доказать, что круговая формула нагружена**

Мутационная проверка: во временной копии заменить `circularSpread` на обычное стандартное отклонение и прогнать тест.
Expected: тест `times around midnight` обязан упасть. Если проходит — тест не отличает круговую формулу от линейной. Вернуть исходный код.

- [ ] **Step 6: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_stability.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_stability_test.dart
git commit -m "feat(sleep): круговой разброс времён

sleep.stability#1 sleep.stability#3"
```

---

## Фаза 3 — хранение

### Task 8: Миграции расширений, таблицы и репозиторий

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/database/extension_migrations.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/database/database.dart`
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_session_repository.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/database/extension_migrations_test.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_session_repository_test.dart`

**Interfaces:**
- Consumes: `SleepEpisode`, `SleepGoal`
- Produces:
  - `const Map<int, String> extensionMigrationSql`, `const int extensionDatabaseVersion = 100`
  - `SleepSessionRepository` с методами `void upsert(int habitId, int day, SleepEpisode episode, {required bool manual})`, `SleepEpisode? forDay(int habitId, int day)`, `Map<int, SleepEpisode> range(int habitId, int fromDay, int toDay)`, `SleepGoal? goalFor(int habitId)`, `void saveGoal(int habitId, SleepGoal goal)`, `Map<int, int> observedOffsets(int habitId, int fromDay, int toDay)`

- [ ] **Step 1: Написать падающий тест на миграцию**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';

void main() {
  test('extension migrations start at 100 and never collide with Kotlin', () {
    expect(databaseVersion, lessThan(100),
        reason: 'sleep.persistence#4');
    for (final version in extensionMigrationSql.keys) {
      expect(version, greaterThanOrEqualTo(100),
          reason: 'sleep.persistence#4');
      expect(migrationSql.containsKey(version), isFalse,
          reason: 'sleep.persistence#4');
    }
    expect(extensionDatabaseVersion, 100, reason: 'sleep.persistence#4');
  });

  test('migration 100 creates both tables', () {
    final sql = extensionMigrationSql[100]!.toLowerCase();
    expect(sql, contains('create table sleepsessions'),
        reason: 'sleep.persistence#1');
    expect(sql, contains('create table sleepgoals'),
        reason: 'sleep.persistence#1');
    expect(sql, contains('unique index'), reason: 'sleep.persistence#5');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/database/extension_migrations_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Написать миграции расширений**

Создать `lib/src/database/extension_migrations.dart`:

```dart
/// Миграции расширений — того, чего в Kotlin-оригинале нет.
///
/// `migrations.g.dart` порождается tool/generate_migrations.dart из
/// Kotlin-ассетов и помечен «do not edit by hand»: дописывать туда нельзя,
/// генератор затрёт. Нумерация начинается со 100 с запасом, чтобы никогда
/// не столкнуться с версиями оригинала (последняя — 25).
library;

const Map<int, String> extensionMigrationSql = {
  100: r"""
create table SleepSessions (
    id integer primary key autoincrement,
    habit integer not null,
    day integer not null,
    bed_start integer not null,
    wake_end integer not null,
    asleep_minutes integer not null,
    derived_from_asleep integer not null,
    utc_offset integer not null,
    source integer not null,
    source_id text,
    updated_at integer not null
);

create unique index idx_sleep_sessions_habit_day
    on SleepSessions(habit, day);

create table SleepGoals (
    habit integer primary key,
    bed_minutes integer not null,
    wake_minutes integer not null,
    min_sleep_minutes integer not null,
    weight_sleep real not null,
    weight_bed real not null,
    weight_wake real not null,
    half_credit_time_minutes integer not null,
    half_credit_sleep_minutes integer not null,
    home_utc_offset integer not null,
    adaptation_minutes_per_day integer not null,
    merge_gap_minutes integer not null,
    prompt_after_wake_minutes integer not null
);""",
};

/// Целевая версия схемы приложения.
const int extensionDatabaseVersion = 100;
```

- [ ] **Step 4: Научить загрузчик двум наборам**

В `lib/src/database/database.dart` найти место, где `MigrationSqlLoader` получает SQL по номеру версии, и сделать так, чтобы версии со 100 брались из `extensionMigrationSql`, а версии до 99 — из `migrationSql`. Версии 26…99 отсутствуют в обоих отображениях: цикл `for (var v = currentVersion + 1; v <= targetVersion; v++)` должен пропускать их, а не падать.

В `migrateTo` заменить обращение к загрузчику на:

```dart
      for (var v = currentVersion + 1; v <= targetVersion; v++) {
        final script = loadSql(v);
        // Версии между последней Kotlin-миграцией и первой миграцией
        // расширений не существуют — это не ошибка, а пустой промежуток.
        if (script.isEmpty) continue;
        _applyScript(script);
      }
```

и там, где загрузчик собирается по умолчанию:

```dart
String defaultMigrationSqlLoader(int version) =>
    version >= 100
        ? (extensionMigrationSql[version] ?? '')
        : (migrationSql[version] ?? '');
```

Целевую версию, передаваемую в `migrateTo`, поменять с `databaseVersion` на `extensionDatabaseVersion` во всех местах вызова.

- [ ] **Step 5: Написать тест на подъём реальной базы**

Добавить в тот же файл теста:

```dart
  test('a version 25 database migrates to 100 without losing habits', () {
    final db = openTestDatabase(); // существующий помощник тестов БД
    db.run('pragma user_version = 25');
    db.run("insert into Habits (id, name, type, position) "
        "values (1, 'Бег', 0, 0)");
    migrateTo(db, extensionDatabaseVersion, defaultMigrationSqlLoader);

    expect(db.queryInt('pragma user_version'), 100,
        reason: 'sleep.persistence#2');
    expect(db.queryInt('select count(*) from Habits'), 1,
        reason: 'sleep.persistence#2');
    expect(db.queryInt('select count(*) from SleepSessions'), 0,
        reason: 'sleep.persistence#1');

    // Повторный прогон безопасен.
    migrateTo(db, extensionDatabaseVersion, defaultMigrationSqlLoader);
    expect(db.queryInt('pragma user_version'), 100,
        reason: 'sleep.persistence#3');
  });
```

Точные имена помощника и сигнатуру `migrateTo` взять из существующего `test/database/database_test.dart` — файл уже поднимает базу и применяет миграции, повторять его инфраструктуру не нужно.

- [ ] **Step 6: Прогнать тесты миграции**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/database/`
Expected: PASS

- [ ] **Step 7: Написать падающий тест репозитория**

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';

void main() {
  test('one night per habit and day', () {
    final repo = SleepSessionRepository(openMigratedTestDatabase());
    const a = SleepEpisode(
      bedStartMillis: 1000, wakeEndMillis: 2000,
      asleepMinutes: 400, utcOffsetMinutes: 180,
    );
    const b = SleepEpisode(
      bedStartMillis: 3000, wakeEndMillis: 4000,
      asleepMinutes: 450, utcOffsetMinutes: 180,
    );
    repo.upsert(1, 9000, a, manual: false);
    repo.upsert(1, 9000, b, manual: false);
    expect(repo.forDay(1, 9000)!.asleepMinutes, 450,
        reason: 'sleep.persistence#5');
  });

  test('a manual entry beats a health entry for the same day', () {
    final repo = SleepSessionRepository(openMigratedTestDatabase());
    const health = SleepEpisode(
      bedStartMillis: 1000, wakeEndMillis: 2000,
      asleepMinutes: 400, utcOffsetMinutes: 0,
    );
    const manual = SleepEpisode(
      bedStartMillis: 3000, wakeEndMillis: 4000,
      asleepMinutes: 450, utcOffsetMinutes: 0,
    );
    repo.upsert(1, 9000, manual, manual: true);
    repo.upsert(1, 9000, health, manual: false);
    expect(repo.forDay(1, 9000)!.asleepMinutes, 450,
        reason: 'sleep.merge#9');
  });

  test('goals round-trip', () {
    final repo = SleepSessionRepository(openMigratedTestDatabase());
    const goal = SleepGoal(
      bedMinutes: 1380, wakeMinutes: 420, homeUtcOffsetMinutes: 180,
    );
    repo.saveGoal(1, goal);
    final loaded = repo.goalFor(1)!;
    expect(loaded.bedMinutes, 1380, reason: 'sleep.persistence#1');
    expect(loaded.homeUtcOffsetMinutes, 180, reason: 'sleep.persistence#1');
    expect(loaded.minSleepMinutes, 450, reason: 'sleep.goal#1');
  });

  test('observed offsets come back keyed by day', () {
    final repo = SleepSessionRepository(openMigratedTestDatabase());
    repo.upsert(1, 9000, const SleepEpisode(
      bedStartMillis: 1, wakeEndMillis: 2,
      asleepMinutes: 400, utcOffsetMinutes: 180,
    ), manual: false);
    repo.upsert(1, 9002, const SleepEpisode(
      bedStartMillis: 1, wakeEndMillis: 2,
      asleepMinutes: 400, utcOffsetMinutes: -240,
    ), manual: false);
    final offsets = repo.observedOffsets(1, 9000, 9002);
    expect(offsets[9000], 180, reason: 'sleep.timezone#5');
    expect(offsets[9002], -240, reason: 'sleep.timezone#5');
    expect(offsets.containsKey(9001), isFalse, reason: 'sleep.timezone#5');
  });
}
```

- [ ] **Step 8: Реализовать репозиторий**

Создать `lib/src/sleep/sleep_session_repository.dart`.

Обратите внимание на реальный API базы: `run(String sql, [void Function(PreparedStatement) bind])` принимает **связывающий вызов**, а не список значений, а `query(String sql, List<String> params, block)` связывает свои параметры как TEXT по индексам с единицы. Индексы связывания начинаются с 1, индексы чтения — с 0. Метки времени в миллисекундах связываются и читаются через `bindLong`/`getLong`: в `int` на 32 битах они не помещаются.

```dart
import '../database/database.dart';
import 'sleep_episode.dart';
import 'sleep_goal.dart';

const int sourceHealth = 0;
const int sourceManual = 1;

class SleepSessionRepository {
  SleepSessionRepository(this._db, this._nowMillis);

  final Database _db;

  /// Часы внедряются, чтобы репозиторий проверялся без обращения к системным.
  final int Function() _nowMillis;

  /// Сохраняет ночь.
  ///
  /// Запись из Health никогда не затирает ручную. Правило живёт здесь, а не
  /// в вызывающем коде, чтобы его нельзя было забыть в одном из мест вызова.
  void upsert(int habitId, int day, SleepEpisode episode,
      {required bool manual}) {
    if (!manual) {
      final existing = _db.querySingle<int>(
        'select count(*) from SleepSessions '
        'where habit = ? and day = ? and source = ?',
        ['$habitId', '$day', '$sourceManual'],
        (stmt) => stmt.getInt(0),
      );
      if ((existing ?? 0) > 0) return;
    }
    _db.run(
      'insert into SleepSessions '
      '(habit, day, bed_start, wake_end, asleep_minutes, derived_from_asleep, '
      ' utc_offset, source, source_id, updated_at) '
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'on conflict(habit, day) do update set '
      ' bed_start = excluded.bed_start, wake_end = excluded.wake_end, '
      ' asleep_minutes = excluded.asleep_minutes, '
      ' derived_from_asleep = excluded.derived_from_asleep, '
      ' utc_offset = excluded.utc_offset, source = excluded.source, '
      ' source_id = excluded.source_id, updated_at = excluded.updated_at',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, day);
        stmt.bindLong(3, episode.bedStartMillis);
        stmt.bindLong(4, episode.wakeEndMillis);
        stmt.bindInt(5, episode.asleepMinutes);
        stmt.bindInt(6, episode.derivedFromAsleep ? 1 : 0);
        stmt.bindInt(7, episode.utcOffsetMinutes);
        stmt.bindInt(8, manual ? sourceManual : sourceHealth);
        stmt.bindText(9, episode.sourceId);
        stmt.bindLong(10, _nowMillis());
      },
    );
  }

  SleepEpisode? forDay(int habitId, int day) => range(habitId, day, day)[day];

  Map<int, SleepEpisode> range(int habitId, int fromDay, int toDay) {
    final result = <int, SleepEpisode>{};
    _db.query(
      'select day, bed_start, wake_end, asleep_minutes, derived_from_asleep, '
      ' utc_offset, source_id from SleepSessions '
      'where habit = ? and day >= ? and day <= ? order by day',
      ['$habitId', '$fromDay', '$toDay'],
      (stmt) {
        result[stmt.getInt(0)] = SleepEpisode(
          bedStartMillis: stmt.getLong(1),
          wakeEndMillis: stmt.getLong(2),
          asleepMinutes: stmt.getInt(3),
          utcOffsetMinutes: stmt.getInt(5),
          derivedFromAsleep: stmt.getInt(4) == 1,
          sourceId: stmt.getTextOrNull(6) ?? '',
        );
      },
    );
    return result;
  }

  /// Смещения, наблюдённые по дням. Дни без ночи в результат не попадают:
  /// наследование ближайшего более раннего — забота effectiveOffsets.
  Map<int, int> observedOffsets(int habitId, int fromDay, int toDay) {
    final result = <int, int>{};
    _db.query(
      'select day, utc_offset from SleepSessions '
      'where habit = ? and day >= ? and day <= ?',
      ['$habitId', '$fromDay', '$toDay'],
      (stmt) => result[stmt.getInt(0)] = stmt.getInt(1),
    );
    return result;
  }

  SleepGoal? goalFor(int habitId) => _db.querySingle<SleepGoal>(
        'select bed_minutes, wake_minutes, min_sleep_minutes, weight_sleep, '
        ' weight_bed, weight_wake, half_credit_time_minutes, '
        ' half_credit_sleep_minutes, home_utc_offset, '
        ' adaptation_minutes_per_day, merge_gap_minutes, '
        ' prompt_after_wake_minutes from SleepGoals where habit = ?',
        ['$habitId'],
        (stmt) => SleepGoal(
          bedMinutes: stmt.getInt(0),
          wakeMinutes: stmt.getInt(1),
          minSleepMinutes: stmt.getInt(2),
          weightSleep: stmt.getReal(3),
          weightBed: stmt.getReal(4),
          weightWake: stmt.getReal(5),
          halfCreditTimeMinutes: stmt.getInt(6),
          halfCreditSleepMinutes: stmt.getInt(7),
          homeUtcOffsetMinutes: stmt.getInt(8),
          adaptationMinutesPerDay: stmt.getInt(9),
          mergeGapMinutes: stmt.getInt(10),
          promptAfterWakeMinutes: stmt.getInt(11),
        ),
      );

  void saveGoal(int habitId, SleepGoal goal) {
    _db.run(
      'insert into SleepGoals (habit, bed_minutes, wake_minutes, '
      ' min_sleep_minutes, weight_sleep, weight_bed, weight_wake, '
      ' half_credit_time_minutes, half_credit_sleep_minutes, '
      ' home_utc_offset, adaptation_minutes_per_day, merge_gap_minutes, '
      ' prompt_after_wake_minutes) '
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'on conflict(habit) do update set '
      ' bed_minutes = excluded.bed_minutes, '
      ' wake_minutes = excluded.wake_minutes, '
      ' min_sleep_minutes = excluded.min_sleep_minutes, '
      ' weight_sleep = excluded.weight_sleep, '
      ' weight_bed = excluded.weight_bed, '
      ' weight_wake = excluded.weight_wake, '
      ' half_credit_time_minutes = excluded.half_credit_time_minutes, '
      ' half_credit_sleep_minutes = excluded.half_credit_sleep_minutes, '
      ' home_utc_offset = excluded.home_utc_offset, '
      ' adaptation_minutes_per_day = excluded.adaptation_minutes_per_day, '
      ' merge_gap_minutes = excluded.merge_gap_minutes, '
      ' prompt_after_wake_minutes = excluded.prompt_after_wake_minutes',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, goal.bedMinutes);
        stmt.bindInt(3, goal.wakeMinutes);
        stmt.bindInt(4, goal.minSleepMinutes);
        stmt.bindReal(5, goal.weightSleep);
        stmt.bindReal(6, goal.weightBed);
        stmt.bindReal(7, goal.weightWake);
        stmt.bindInt(8, goal.halfCreditTimeMinutes);
        stmt.bindInt(9, goal.halfCreditSleepMinutes);
        stmt.bindInt(10, goal.homeUtcOffsetMinutes);
        stmt.bindInt(11, goal.adaptationMinutesPerDay);
        stmt.bindInt(12, goal.mergeGapMinutes);
        stmt.bindInt(13, goal.promptAfterWakeMinutes);
      },
    );
  }
}
```

- [ ] **Step 9: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/ test/database/`
Expected: PASS

- [ ] **Step 10: Прогнать весь набор ядра**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test`
Expected: PASS, 1603 существующих теста в том числе.

- [ ] **Step 11: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/database/extension_migrations.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/database/database.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_session_repository.dart \
        uhabits-flutter/packages/uhabits_core/test/database/extension_migrations_test.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_session_repository_test.dart
git commit -m "feat(sleep): таблицы ночей и целей, миграции расширений

Отдельный набор миграций со 100: migrations.g.dart генерируется из
Kotlin-ассетов и правку не переживёт.

sleep.persistence#1..#5 sleep.merge#9"
```

---

## Фаза 4 — платформа

### Task 9: Плагин HealthKit

**Files:**
- Create: `uhabits-flutter/app/ios/Runner/HealthKitSleepPlugin.swift`
- Create: `uhabits-flutter/app/lib/platform/health_kit_sleep_source.dart`
- Modify: `uhabits-flutter/app/ios/Runner/AppDelegate.swift`
- Modify: `uhabits-flutter/app/ios/Runner/Info.plist`
- Modify: `uhabits-flutter/app/ios/Runner.xcodeproj/project.pbxproj`
- Test: `uhabits-flutter/app/test/platform/health_kit_sleep_source_test.dart`
- Test: `uhabits-flutter/app/ios/RunnerTests/HealthKitWindowTests.swift`

**Interfaces:**
- Consumes: `SleepSegment`, `SleepSegmentKind` из Task 6
- Produces: `abstract class SleepDataSource` с методами `Future<bool> requestAuthorization()`, `Future<bool> get isAuthorized`, `Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis)`, `Future<void> writeSession(int startMillis, int endMillis)`, `Future<void> enableBackgroundDelivery()`; реализация `HealthKitSleepSource` поверх `MethodChannel('org.isoron.uhabits/health_sleep')`

- [ ] **Step 1: Написать падающий тест Dart-стороны**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/health_kit_sleep_source.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.isoron.uhabits/health_sleep');
  final log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      if (call.method == 'readSegments') {
        return <Map<Object?, Object?>>[
          {
            'start': 1000,
            'end': 2000,
            'kind': 'asleepCore',
            'source': 'com.apple.health.watch',
          },
          {
            'start': 500,
            'end': 2500,
            'kind': 'inBed',
            'source': 'com.apple.health.watch',
          },
          {'start': 0, 'end': 1, 'kind': 'somethingNew', 'source': 'x'},
        ];
      }
      if (call.method == 'requestAuthorization') return true;
      return null;
    });
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('segments are decoded into core value objects', () async {
    final source = HealthKitSleepSource();
    final segments = await source.readSegments(0, 10000);
    expect(segments.length, 2, reason: 'sleep.sync#5');
    expect(segments.first.kind, SleepSegmentKind.asleepCore,
        reason: 'sleep.sync#5');
    expect(segments.first.sourceId, 'com.apple.health.watch',
        reason: 'sleep.sync#5');
  });

  test('an unknown kind is dropped rather than crashing the sync', () async {
    // Apple добавляет новые значения в HKCategoryValueSleepAnalysis между
    // версиями iOS. Неизвестный вид не должен ронять синхронизацию.
    final source = HealthKitSleepSource();
    final segments = await source.readSegments(0, 10000);
    expect(segments.any((s) => s.sourceId == 'x'), isFalse,
        reason: 'sleep.sync#5');
  });

  test('a denied authorization is not an error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'denied');
    });
    final source = HealthKitSleepSource();
    expect(await source.readSegments(0, 1), isEmpty, reason: 'sleep.sync#5');
    expect(await source.requestAuthorization(), isFalse,
        reason: 'sleep.sync#5');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/platform/health_kit_sleep_source_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать Dart-сторону**

```dart
import 'package:flutter/services.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';

/// Источник данных о сне. Абстракция нужна, чтобы синхронизация
/// тестировалась без платформы, а Android работал без источника вовсе.
abstract class SleepDataSource {
  Future<bool> requestAuthorization();
  Future<bool> get isAuthorized;
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis);
  Future<void> writeSession(int startMillis, int endMillis);
  Future<void> enableBackgroundDelivery();
}

/// Источник, которого нет: Android и любая платформа без Health.
class NoSleepDataSource implements SleepDataSource {
  const NoSleepDataSource();
  @override
  Future<bool> requestAuthorization() async => false;
  @override
  Future<bool> get isAuthorized async => false;
  @override
  Future<List<SleepSegment>> readSegments(int f, int t) async => const [];
  @override
  Future<void> writeSession(int s, int e) async {}
  @override
  Future<void> enableBackgroundDelivery() async {}
}

const _kinds = <String, SleepSegmentKind>{
  'inBed': SleepSegmentKind.inBed,
  'asleepCore': SleepSegmentKind.asleepCore,
  'asleepDeep': SleepSegmentKind.asleepDeep,
  'asleepREM': SleepSegmentKind.asleepRem,
  'asleepUnspecified': SleepSegmentKind.asleepUnspecified,
  'awake': SleepSegmentKind.awake,
};

class HealthKitSleepSource implements SleepDataSource {
  static const MethodChannel _channel =
      MethodChannel('org.isoron.uhabits/health_sleep');

  @override
  Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
    } on PlatformException {
      // Отказ — это не ошибка: привычка продолжает жить на ручном вводе.
      return false;
    }
  }

  @override
  Future<bool> get isAuthorized async {
    try {
      return await _channel.invokeMethod<bool>('authorizationStatus') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis) async {
    final List<Object?>? raw;
    try {
      raw = await _channel.invokeMethod<List<Object?>>(
        'readSegments',
        {'from': fromMillis, 'to': toMillis},
      );
    } on PlatformException {
      return const [];
    }
    if (raw == null) return const [];

    final result = <SleepSegment>[];
    for (final item in raw) {
      final map = (item as Map).cast<Object?, Object?>();
      // Apple добавляет значения между версиями iOS: неизвестный вид
      // пропускается, а не роняет синхронизацию.
      final kind = _kinds[map['kind'] as String?];
      if (kind == null) continue;
      result.add(SleepSegment(
        startMillis: map['start'] as int,
        endMillis: map['end'] as int,
        kind: kind,
        sourceId: (map['source'] as String?) ?? '',
      ));
    }
    return result;
  }

  @override
  Future<void> writeSession(int startMillis, int endMillis) async {
    try {
      await _channel.invokeMethod<void>(
        'writeSession',
        {'start': startMillis, 'end': endMillis},
      );
    } on PlatformException {
      // Запись в Health необязательна: ночь уже сохранена у нас.
    }
  }

  @override
  Future<void> enableBackgroundDelivery() async {
    try {
      await _channel.invokeMethod<void>('enableBackgroundDelivery');
    } on PlatformException {
      // Фоновая доставка — удобство, её отсутствие не ломает фичу.
    }
  }
}
```

- [ ] **Step 4: Прогнать тесты Dart-стороны**

Run: `cd uhabits-flutter/app && flutter test test/platform/health_kit_sleep_source_test.dart`
Expected: PASS

- [ ] **Step 5: Реализовать плагин Swift**

Создать `ios/Runner/HealthKitSleepPlugin.swift`. Логики в нём нет: он запрашивает доступ, отдаёт сырые отрезки и принимает запись.

```swift
import Foundation
import HealthKit

/// Доступ к данным сна HealthKit. Намеренно лишён логики: склейка,
/// дедупликация и оценка живут в Dart, где покрываются тестами.
final class HealthKitSleepPlugin: NSObject {
  private let store = HKHealthStore()
  private var observerQuery: HKObserverQuery?

  private var sleepType: HKCategoryType {
    HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
  }

  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(false)
      return
    }
    store.requestAuthorization(
      toShare: [sleepType], read: [sleepType]
    ) { granted, _ in
      DispatchQueue.main.async { completion(granted) }
    }
  }

  func readSegments(
    fromMillis: Int, toMillis: Int,
    completion: @escaping ([[String: Any]]) -> Void
  ) {
    let predicate = HKQuery.predicateForSamples(
      withStart: Date(timeIntervalSince1970: Double(fromMillis) / 1000),
      end: Date(timeIntervalSince1970: Double(toMillis) / 1000),
      options: [.strictStartDate]
    )
    let query = HKSampleQuery(
      sampleType: sleepType, predicate: predicate,
      limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { _, samples, _ in
      let result = (samples as? [HKCategorySample] ?? []).compactMap {
        Self.encode($0)
      }
      DispatchQueue.main.async { completion(result) }
    }
    store.execute(query)
  }

  /// Отображение значений HealthKit в строки канала. Значения, добавленные
  /// в будущих версиях iOS, отдаются как есть и отбрасываются в Dart.
  static func kindName(for value: Int) -> String {
    switch value {
    case HKCategoryValueSleepAnalysis.inBed.rawValue: return "inBed"
    case HKCategoryValueSleepAnalysis.awake.rawValue: return "awake"
    case HKCategoryValueSleepAnalysis.asleepCore.rawValue: return "asleepCore"
    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: return "asleepDeep"
    case HKCategoryValueSleepAnalysis.asleepREM.rawValue: return "asleepREM"
    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
      return "asleepUnspecified"
    default: return "unknown"
    }
  }

  static func encode(_ sample: HKCategorySample) -> [String: Any] {
    [
      "start": Int(sample.startDate.timeIntervalSince1970 * 1000),
      "end": Int(sample.endDate.timeIntervalSince1970 * 1000),
      "kind": kindName(for: sample.value),
      "source": sample.sourceRevision.source.bundleIdentifier,
    ]
  }

  func writeSession(
    fromMillis: Int, toMillis: Int, completion: @escaping (Bool) -> Void
  ) {
    let sample = HKCategorySample(
      type: sleepType,
      value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
      start: Date(timeIntervalSince1970: Double(fromMillis) / 1000),
      end: Date(timeIntervalSince1970: Double(toMillis) / 1000)
    )
    store.save(sample) { ok, _ in
      DispatchQueue.main.async { completion(ok) }
    }
  }

  func enableBackgroundDelivery(onChange: @escaping () -> Void) {
    let query = HKObserverQuery(
      sampleType: sleepType, predicate: nil
    ) { _, completionHandler, _ in
      DispatchQueue.main.async { onChange() }
      completionHandler()
    }
    store.execute(query)
    observerQuery = query
    store.enableBackgroundDelivery(
      for: sleepType, frequency: .hourly
    ) { _, _ in }
  }
}
```

Зарегистрировать канал в `AppDelegate.swift` рядом с существующей регистрацией каналов, вызывая методы плагина и отвечая через `result(...)`. Метод `enableBackgroundDelivery` при срабатывании отправляет в Dart `invokeMethod("healthDataChanged")` по тому же каналу.

- [ ] **Step 6: Добавить ключи и возможности**

В `ios/Runner/Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Приложение читает данные сна, чтобы оценивать вашу цель по сну.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Приложение сохраняет введённые вручную ночи в «Здоровье».</string>
```

В `project.pbxproj` цели Runner добавить возможность HealthKit и `HealthKit.framework`, а в `UIBackgroundModes` — `processing`, необходимый для фоновой доставки.

- [ ] **Step 7: Написать Swift-тест на отображение видов**

Создать `ios/RunnerTests/HealthKitWindowTests.swift`. Отображение значений — единственная арифметика плагина, и её надо исполнять, а не вычитывать глазами:

```swift
import XCTest
import HealthKit
@testable import Runner

final class HealthKitWindowTests: XCTestCase {
  func testKnownSleepValuesMapToChannelNames() {
    XCTAssertEqual(
      HealthKitSleepPlugin.kindName(
        for: HKCategoryValueSleepAnalysis.inBed.rawValue),
      "inBed")
    XCTAssertEqual(
      HealthKitSleepPlugin.kindName(
        for: HKCategoryValueSleepAnalysis.asleepREM.rawValue),
      "asleepREM")
    XCTAssertEqual(
      HealthKitSleepPlugin.kindName(
        for: HKCategoryValueSleepAnalysis.awake.rawValue),
      "awake")
  }

  func testUnknownValueDoesNotMasqueradeAsSleep() {
    // Новое значение из будущей версии iOS обязано прийти как "unknown",
    // а не как случайный из известных видов.
    XCTAssertEqual(HealthKitSleepPlugin.kindName(for: 9999), "unknown")
  }
}
```

Добавить файл в цель `RunnerTests` в `project.pbxproj`, как это уже сделано для `WidgetArithmeticTests.swift`.

- [ ] **Step 8: Прогнать Swift-тесты**

Run: `cd uhabits-flutter && tool/swift_widget_tests.sh`
Expected: PASS, 19 существующих тестов плюс новые.

- [ ] **Step 9: Собрать под устройство**

Run: `cd uhabits-flutter/app && flutter build ios --release --no-codesign`
Expected: сборка проходит.

- [ ] **Step 10: Коммит**

```bash
git add uhabits-flutter/app/ios/Runner/HealthKitSleepPlugin.swift \
        uhabits-flutter/app/ios/Runner/AppDelegate.swift \
        uhabits-flutter/app/ios/Runner/Info.plist \
        uhabits-flutter/app/ios/Runner.xcodeproj/project.pbxproj \
        uhabits-flutter/app/ios/RunnerTests/HealthKitWindowTests.swift \
        uhabits-flutter/app/lib/platform/health_kit_sleep_source.dart \
        uhabits-flutter/app/test/platform/health_kit_sleep_source_test.dart
git commit -m "feat(sleep): плагин HealthKit и Dart-сторона канала

Плагин лишён логики: отдаёт сырые отрезки, вся обработка в Dart.
Неизвестный вид отрезка отбрасывается, а не роняет синхронизацию.

sleep.sync#5"
```

---

### Task 10: Синхронизация и пересчёт

**Files:**
- Create: `uhabits-flutter/app/lib/state/sleep_sync.dart`
- Test: `uhabits-flutter/app/test/state/sleep_sync_test.dart`

**Interfaces:**
- Consumes: всё из задач 2–9
- Produces: `SleepSync` с методами `Future<void> syncRecent(int habitId)`, `Future<void> recomputeAll(int habitId)`, `Future<void> recomputeDays(int habitId, int fromDay, int toDay)`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/sleep_sync.dart';

void main() {
  test('the recent window covers fourteen days, not one', () async {
    final source = RecordingSleepSource();
    final sync = buildTestSync(source: source, today: 9000);
    await sync.syncRecent(1);
    expect(source.lastWindowDays, 14, reason: 'sleep.sync#1');
  });

  test('running the fold twice yields identical entries', () async {
    final sync = buildTestSync(segments: twoWeeksOfNights());
    await sync.syncRecent(1);
    final first = readEntries(sync, 1);
    await sync.syncRecent(1);
    final second = readEntries(sync, 1);
    expect(second, equals(first), reason: 'sleep.sync#2');
  });

  test('a day without data is never written as a synthetic zero', () async {
    final sync = buildTestSync(segments: const []);
    await sync.syncRecent(1);
    expect(readEntries(sync, 1), isEmpty, reason: 'sleep.sync#4');
  });

  test('late arriving data heals a past day', () async {
    final sync = buildTestSync(segments: const []);
    await sync.syncRecent(1);
    expect(readEntries(sync, 1), isEmpty, reason: 'sleep.sync#4');
    sync.source.segments = nightOn(8995);
    await sync.syncRecent(1);
    expect(readEntries(sync, 1).containsKey(8995), isTrue,
        reason: 'sleep.sync#4');
  });

  test('changing the goal recomputes the whole history', () async {
    final sync = buildTestSync(segments: twoMonthsOfNights());
    await sync.syncRecent(1);
    await sync.recomputeAll(1);
    final before = readEntries(sync, 1);

    sync.repository.saveGoal(1, const SleepGoal(
      bedMinutes: 1320, wakeMinutes: 360, // цель сдвинута на час
    ));
    await sync.recomputeAll(1);
    final after = readEntries(sync, 1);

    // Меняется вся история, а не только последние две недели.
    final oldestDay = before.keys.reduce((a, b) => a < b ? a : b);
    expect(after[oldestDay], isNot(equals(before[oldestDay])),
        reason: 'sleep.sync#3');
  });

  test('a denied source leaves the habit usable', () async {
    final sync = buildTestSync(source: DeniedSleepSource());
    await sync.syncRecent(1);
    expect(readEntries(sync, 1), isEmpty, reason: 'sleep.sync#5');
  });
}
```

Помощники `buildTestSync`, `readEntries`, `nightOn`, `twoWeeksOfNights`, `twoMonthsOfNights`, `RecordingSleepSource` и `DeniedSleepSource` написать в том же файле: `RecordingSleepSource` запоминает окно последнего запроса, `DeniedSleepSource` всегда возвращает пустой список.

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/state/sleep_sync_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать оркестровку**

Создать `app/lib/state/sleep_sync.dart`. Порядок: прочитать отрезки за окно → разложить по логическим дням → склеить каждый день → сохранить ночи → пересчитать записи.

Ключевые решения, которые нельзя потерять при реализации:

```dart
/// Окно перечитывания. Не «вчера», а две недели: часы выгружают ночь с
/// задержкой, а данные в Health можно править задним числом.
const int recentWindowDays = 14;

Future<void> syncRecent(int habitId) async {
  final goal = _repository.goalFor(habitId);
  if (goal == null) return;

  final today = _clock.todayDay();
  final fromDay = today - recentWindowDays + 1;

  // Окно запроса шире окна дней: ночь дня D начинается накануне.
  final segments = await _source.readSegments(
    _millisOfDayStart(fromDay - 1),
    _millisOfDayEnd(today),
  );

  // Логический день ночи — календарная дата пробуждения. Настройка
  // сдвига полуночи сюда НЕ применяется: у привычки со сном граница
  // суток задаётся пробуждением, и два разных понятия дня под одним
  // именем породили бы расхождение, невидимое в день правки.
  final byDay = _groupByWakeDay(segments);

  for (var day = fromDay; day <= today; day++) {
    final episode = mergeSegments(
      byDay[day] ?? const [],
      mergeGapMinutes: goal.mergeGapMinutes,
      utcOffsetMinutes: _clock.utcOffsetMinutesAt(day),
    );
    if (episode == null) continue; // синтетический ноль не пишем
    _repository.upsert(habitId, day, episode, manual: false);
  }

  await recomputeDays(habitId, fromDay, today);
}
```

Пересчёт дня: взять ночь, получить действующий пояс через `effectiveOffsets`, оценить через `scoreNight`, записать `storedValue` в запись дня. Дни без ночи не трогать вовсе — ни записи, ни удаления.

`recomputeAll` вызывает `recomputeDays` от дня первой ночи привычки до сегодня. Вызывается при сохранении цели, потому что смена цели меняет проценты всей истории: иначе история окажется смесью старой и новой шкалы, и обнаружится это далеко не в день правки.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/state/sleep_sync_test.dart`
Expected: PASS

- [ ] **Step 5: Подключить к жизненному циклу**

В существующем месте, где приложение реагирует на выход на передний план (см. `test/state/foreground_resume_wiring_test.dart` — там уже проверяется эта проводка), добавить вызов `syncRecent` для каждой привычки со сном. Туда же — обработчик `healthDataChanged` из плагина.

- [ ] **Step 6: Прогнать весь набор приложения**

Run: `cd uhabits-flutter/app && flutter test`
Expected: PASS, 1947 существующих тестов в том числе.

- [ ] **Step 7: Коммит**

```bash
git add uhabits-flutter/app/lib/state/sleep_sync.dart \
        uhabits-flutter/app/test/state/sleep_sync_test.dart
git commit -m "feat(sleep): синхронизация и пересчёт

Окно две недели, идемпотентная свёртка, полный пересчёт истории при
смене цели, никаких синтетических нулей.

sleep.sync#1..#5"
```

---

## Фаза 5 — интерфейс

### Task 11: Блок «прошлая ночь»

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/last_night_card.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/last_night_card_test.dart`

**Interfaces:**
- Consumes: `SleepBreakdown`, `SleepComponent` из Task 4
- Produces: `LastNightCard({required SleepBreakdown? breakdown, required double habitScore, required int streakDays})`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/sleep/last_night_card.dart';

void main() {
  testWidgets('shows the percent and all three components', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LastNightCard(
          breakdown: breakdownFor(bed: 1421, wake: 432, asleep: 408),
          habitScore: 0.78,
          streakDays: 12,
        ),
      ),
    ));
    expect(find.text('87%'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('23:41'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('07:12'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('6:48'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('93%'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('99%'), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.text('75%'), findsOneWidget, reason: 'sleep.ui#2');
  });

  testWidgets('names the component that cost the most', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LastNightCard(
          breakdown: breakdownFor(bed: 1380, wake: 420, asleep: 300),
          habitScore: 0.5,
          streakDays: 1,
        ),
      ),
    ));
    expect(find.textContaining('длительность'), findsOneWidget,
        reason: 'sleep.scoring#8');
  });

  testWidgets('survives having no data at all', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: LastNightCard(breakdown: null, habitScore: 0, streakDays: 0),
      ),
    ));
    expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
    expect(find.textContaining('Нет данных'), findsOneWidget,
        reason: 'sleep.ui#5');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/last_night_card_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать блок**

Собрать по утверждённому макету `docs/superpowers/specs/2026-08-25-sleep-goal-screen.html` (открыть в браузере): крупным числом процент ночи, рядом мелким — оценка привычки и серия, ниже три карточки составляющих, ниже строка-объяснение. Цвета брать из темы, а не константами: приложение поддерживает светлую, тёмную и истинно чёрную темы, и жёстко заданный цвет проявится только в одной из них.

Форматирование времени — через существующий помощник локали приложения, не через `toString()`: приложение уже следует локали устройства.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/last_night_card_test.dart`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/sleep/last_night_card.dart \
        uhabits-flutter/app/test/ui/sleep/last_night_card_test.dart
git commit -m "feat(sleep): блок прошлой ночи

sleep.ui#2 sleep.ui#5 sleep.scoring#8"
```

---

### Task 12: Лента ночей

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/nights_chart.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/nights_chart_test.dart`

**Interfaces:**
- Consumes: `SleepEpisode`, `SleepGoal`
- Produces: `NightsChart({required Map<int, SleepEpisode> nights, required Set<int> skippedDays, required SleepGoal goal, required Map<int, int> effectiveOffsets, required int lastDay})`

- [ ] **Step 1: Написать падающие тесты**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/sleep/nights_chart.dart';

void main() {
  testWidgets('days run left to right, newest on the right', (tester) async {
    await tester.pumpWidget(chartWith(days: [8990, 8991, 8992]));
    final bars = tester.widgetList<NightBar>(find.byType(NightBar)).toList();
    expect(bars.first.day, 8990, reason: 'sleep.ui#3');
    expect(bars.last.day, 8992, reason: 'sleep.ui#3');
    final firstX = tester.getCenter(find.byType(NightBar).first).dx;
    final lastX = tester.getCenter(find.byType(NightBar).last).dx;
    expect(lastX, greaterThan(firstX), reason: 'sleep.ui#3');
  });

  testWidgets('a later bedtime sits lower on the chart', (tester) async {
    // Время идёт сверху вниз: отбой в час ночи ниже отбоя в 23:00.
    await tester.pumpWidget(chartWith(
      days: [8990, 8991],
      bedMinutes: {8990: 1380, 8991: 1500},
    ));
    final bars = find.byType(NightBar);
    expect(tester.getTopLeft(bars.at(1)).dy,
        greaterThan(tester.getTopLeft(bars.at(0)).dy),
        reason: 'sleep.ui#3');
  });

  testWidgets('skipped days are hatched, not drawn as bars', (tester) async {
    await tester.pumpWidget(chartWith(days: [8990, 8991], skipped: {8991}));
    expect(find.byType(NightBar), findsOneWidget, reason: 'sleep.ui#4');
    expect(find.byType(SkippedDayMark), findsOneWidget, reason: 'sleep.ui#4');
  });

  testWidgets('an empty chart renders without throwing', (tester) async {
    await tester.pumpWidget(chartWith(days: const []));
    expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
  });

  testWidgets('the chart scrolls horizontally', (tester) async {
    await tester.pumpWidget(chartWith(
      days: List.generate(60, (i) => 8950 + i),
    ));
    expect(find.byType(Scrollable), findsWidgets, reason: 'sleep.ui#3');
    await tester.drag(find.byType(NightsChart), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'sleep.ui#3');
  });
}
```

Помощник `chartWith` собирает виджет в `MaterialApp` с заданным набором дней; `NightBar` и `SkippedDayMark` — публичные виджеты-элементы ленты, вынесенные наружу именно для того, чтобы тест мог их найти и измерить.

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/nights_chart_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать ленту**

Ориентация — дни по горизонтали, время по вертикали, как во всех остальных графиках приложения. Прокрутка вбок, как у существующих графиков; взять их способ прокрутки, а не изобретать свой. Целевое окно — горизонтальная полоса, положение которой берётся из `effectiveOffsets` для каждого дня: при дрейфе пояса полоса не горизонтальна, а ступенчата, и это правильно.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/nights_chart_test.dart`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/sleep/nights_chart.dart \
        uhabits-flutter/app/test/ui/sleep/nights_chart_test.dart
git commit -m "feat(sleep): лента ночей

sleep.ui#3 sleep.ui#4 sleep.ui#5"
```

---

### Task 13: Стабильность, пропуски и отметка диапазона

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/stability_card.dart`
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/skip_range_sheet.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/stability_card_test.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/skip_range_test.dart`

**Interfaces:**
- Consumes: `SleepStability` из Task 7, `EntryList.countSkippedDays`
- Produces: `StabilityCard({required SleepStability? stability})`, `SkipCard({required int skippedDays, required int windowDays, required int? lastSkippedDay, required VoidCallback onMark})`, `Future<DateTimeRange?> showSkipRangeSheet(BuildContext)`

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  testWidgets('spreads are shown in minutes', (tester) async {
    await tester.pumpWidget(cardWith(bedSpread: 38, wakeSpread: 22,
        meanAsleep: 424, nights: 14));
    expect(find.text('±38 мин'), findsOneWidget, reason: 'sleep.stability#1');
    expect(find.text('±22 мин'), findsOneWidget, reason: 'sleep.stability#1');
    expect(find.text('7:04'), findsOneWidget, reason: 'sleep.stability#1');
  });

  testWidgets('too few nights hide the spread instead of showing zero',
      (tester) async {
    await tester.pumpWidget(cardWith(stability: null));
    expect(find.textContaining('±'), findsNothing,
        reason: 'sleep.stability#3');
    expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
  });

  testWidgets('the skip counter shows the window', (tester) async {
    await tester.pumpWidget(skipCardWith(skipped: 2, window: 30));
    expect(find.textContaining('2 из 30'), findsOneWidget,
        reason: 'sleep.skip#3');
  });

  testWidgets('marking a range writes a skip on every day', (tester) async {
    final entries = await markRange(from: 8990, to: 8993);
    expect(entries.keys, containsAll([8990, 8991, 8992, 8993]),
        reason: 'sleep.skip#1');
    expect(entries.values.every((v) => v == Entry.skip), isTrue,
        reason: 'sleep.skip#1');
  });

  testWidgets('a past range is accepted', (tester) async {
    final entries = await markRange(from: 8900, to: 8902, today: 9000);
    expect(entries.length, 3, reason: 'sleep.skip#2');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/`
Expected: FAIL — файлы не существуют.

- [ ] **Step 3: Реализовать блоки и лист выбора диапазона**

Счётчик пропусков берёт число из `EntryList.countSkippedDays` за 30 дней — не считать самостоятельно, метод уже есть и уже проверен. Лист выбора диапазона пишет `Entry.skip` на каждый день выбранного отрезка включительно, без ограничения по дате.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/sleep/stability_card.dart \
        uhabits-flutter/app/lib/ui/habits/sleep/skip_range_sheet.dart \
        uhabits-flutter/app/test/ui/sleep/stability_card_test.dart \
        uhabits-flutter/app/test/ui/sleep/skip_range_test.dart
git commit -m "feat(sleep): стабильность и пропуски

sleep.stability#1 sleep.stability#3 sleep.skip#1 sleep.skip#2 sleep.skip#3"
```

---

### Task 14: Ручной ввод

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/manual_entry_sheet.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/manual_entry_test.dart`

**Interfaces:**
- Consumes: `SleepSessionRepository`, `SleepDataSource`
- Produces: `Future<SleepEpisode?> showManualEntrySheet(BuildContext, {SleepEpisode? initial, required SleepGoal goal})`

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  testWidgets('actual sleep defaults to the span between the two times',
      (tester) async {
    final episode = await enterNight(tester, bed: '23:00', wake: '07:00');
    expect(episode!.asleepMinutes, 480, reason: 'sleep.merge#5');
  });

  testWidgets('actual sleep can be shorter than the span', (tester) async {
    final episode = await enterNight(
        tester, bed: '23:00', wake: '07:00', asleepMinutes: 300);
    expect(episode!.asleepMinutes, 300, reason: 'sleep.scoring#6');
    expect(episode.wakeEndMillis - episode.bedStartMillis,
        480 * 60000, reason: 'sleep.scoring#6');
  });

  testWidgets('a manual night is written back to Health', (tester) async {
    final source = RecordingSleepSource();
    await enterNight(tester, bed: '23:00', wake: '07:00', source: source);
    expect(source.written.length, 1, reason: 'sleep.sync#5');
  });

  testWidgets('a manual night survives a later health sync', (tester) async {
    // Ручная запись побеждает — правило живёт в репозитории, здесь
    // проверяется, что путь ввода действительно помечает её ручной.
    final repo = await enterNightIntoRepository(
        bed: '23:00', wake: '07:00', day: 9000);
    repo.upsert(1, 9000, someHealthEpisode(), manual: false);
    expect(repo.forDay(1, 9000)!.asleepMinutes, 480, reason: 'sleep.merge#9');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/manual_entry_test.dart`
Expected: FAIL — файл не существует.

- [ ] **Step 3: Реализовать лист ввода**

Два выбора времени и необязательное поле фактического сна, по умолчанию равное разности. Сохранение пишет ночь с `manual: true` и отправляет её в Health через `writeSession`, если доступ есть; отсутствие доступа сохранение не срывает.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/manual_entry_test.dart`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/sleep/manual_entry_sheet.dart \
        uhabits-flutter/app/test/ui/sleep/manual_entry_test.dart
git commit -m "feat(sleep): ручной ввод ночи

sleep.scoring#6 sleep.merge#9 sleep.sync#5"
```

---

### Task 15: Поля редактора и сборка экрана

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/sleep/sleep_goal_fields.dart`
- Modify: `uhabits-flutter/app/lib/ui/habits/edit/edit_habit_screen.dart`
- Modify: `uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/sleep_goal_fields_test.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/sleep_habit_screen_test.dart`

**Interfaces:**
- Consumes: все блоки задач 11–14
- Produces: экран привычки со сном целиком

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  testWidgets('the editor shows sleep fields instead of numerical ones',
      (tester) async {
    await tester.pumpWidget(editorFor(HabitType.sleep));
    expect(find.text('Целевое время отхода'), findsOneWidget,
        reason: 'sleep.ui#6');
    expect(find.text('Целевое время подъёма'), findsOneWidget,
        reason: 'sleep.ui#6');
    expect(find.text('Минимум сна'), findsOneWidget, reason: 'sleep.ui#6');
    expect(find.text('Единица измерения'), findsNothing,
        reason: 'sleep.ui#6');
  });

  testWidgets('numerical habits are untouched', (tester) async {
    await tester.pumpWidget(editorFor(HabitType.numerical));
    expect(find.text('Единица измерения'), findsOneWidget,
        reason: 'sleep.ui#6');
    expect(find.text('Целевое время отхода'), findsNothing,
        reason: 'sleep.ui#6');
  });

  testWidgets('saving the goal recomputes the whole history', (tester) async {
    final sync = await saveGoalFromEditor(bedMinutes: 1320);
    expect(sync.recomputeAllCalls, 1, reason: 'sleep.sync#3');
  });

  testWidgets('the sleep habit screen shows all four new blocks',
      (tester) async {
    await tester.pumpWidget(sleepHabitScreen());
    expect(find.byType(LastNightCard), findsOneWidget, reason: 'sleep.ui#2');
    expect(find.byType(NightsChart), findsOneWidget, reason: 'sleep.ui#3');
    expect(find.byType(StabilityCard), findsOneWidget,
        reason: 'sleep.stability#1');
    expect(find.byType(SkipCard), findsOneWidget, reason: 'sleep.skip#3');
  });

  testWidgets('the screen works with health access denied', (tester) async {
    await tester.pumpWidget(sleepHabitScreen(authorized: false));
    expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
    expect(find.byType(LastNightCard), findsOneWidget, reason: 'sleep.ui#5');
  });

  testWidgets('the list cell shows the percent', (tester) async {
    await tester.pumpWidget(habitListWithSleepHabit(percent: 87));
    expect(find.text('87'), findsOneWidget, reason: 'sleep.ui#1');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/`
Expected: FAIL.

- [ ] **Step 3: Реализовать поля и собрать экран**

Поля редактора для типа «сон»: целевое время отхода, целевое время подъёма, минимум сна, домашний часовой пояс, скорость адаптации. Веса и точки половинного балла — в раскрывающемся разделе для продвинутых, со значениями по умолчанию.

Сохранение цели вызывает `recomputeAll`, а не только пересчёт последних дней.

Экран привычки: четыре новых блока сверху, существующие блоки ниже без изменений.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/`
Expected: PASS

- [ ] **Step 5: Прогнать весь набор приложения**

Run: `cd uhabits-flutter/app && flutter test && flutter analyze`
Expected: PASS, анализатор чист.

- [ ] **Step 6: Коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/sleep/sleep_goal_fields.dart \
        uhabits-flutter/app/lib/ui/habits/edit/edit_habit_screen.dart \
        uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart \
        uhabits-flutter/app/test/ui/sleep/
git commit -m "feat(sleep): поля редактора и сборка экрана привычки

sleep.ui#1 sleep.ui#2 sleep.ui#3 sleep.ui#5 sleep.ui#6 sleep.sync#3"
```

---

## Фаза 6 — подсказки, напоминание, экспорт

### Task 16: Утреннее напоминание

**Files:**
- Modify: `uhabits-flutter/app/lib/platform/flutter_alarm_scheduler.dart`
- Create: `uhabits-flutter/app/lib/state/sleep_reminder.dart`
- Test: `uhabits-flutter/app/test/platform/sleep_reminder_test.dart`

**Interfaces:**
- Consumes: `SleepGoal`, `effectiveOffsets`, существующий планировщик будильников
- Produces: `SleepReminderScheduler.scheduleFor(int habitId)`

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  test('fires an hour after the wake target', () {
    final at = nextReminderMillis(
      goal: const SleepGoal(bedMinutes: 1380, wakeMinutes: 420),
      effectiveOffsetMinutes: 0,
      nowMillis: millisAt(day: 9000, minutes: 300),
    );
    expect(localMinutesOf(at, 0), 480, reason: 'sleep.reminder#1');
  });

  test('travels with the drifting goal', () {
    // Пояс цели отстаёт от местного на три часа: напоминание едет вместе
    // с ней, а не остаётся на месте.
    final home = nextReminderMillis(
      goal: const SleepGoal(bedMinutes: 1380, wakeMinutes: 420),
      effectiveOffsetMinutes: 0,
      nowMillis: millisAt(day: 9000, minutes: 300),
    );
    final drifted = nextReminderMillis(
      goal: const SleepGoal(bedMinutes: 1380, wakeMinutes: 420),
      effectiveOffsetMinutes: 180,
      nowMillis: millisAt(day: 9000, minutes: 300),
    );
    expect(drifted - home, -180 * 60000, reason: 'sleep.reminder#2');
  });

  test('does not fire when the night is already recorded', () async {
    final scheduler = buildScheduler(nightsPresent: {9000});
    await scheduler.scheduleFor(1);
    expect(scheduler.scheduled, isEmpty, reason: 'sleep.reminder#3');
  });

  test('uses a non-zero timezone in at least one case', () {
    // Все существующие тесты напоминаний пинят FixedTimeZone(0) — то самое
    // смещение, на котором ошибка приведения времени не проявляется.
    final at = nextReminderMillis(
      goal: const SleepGoal(bedMinutes: 1380, wakeMinutes: 420),
      effectiveOffsetMinutes: -240,
      nowMillis: millisAt(day: 9000, minutes: 300),
    );
    expect(localMinutesOf(at, -240), 480, reason: 'sleep.reminder#1');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/app && flutter test test/platform/sleep_reminder_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализовать**

Момент напоминания: `wakeMinutes + promptAfterWakeMinutes` в действующем поясе цели. Действия уведомления: «Ввести» открывает лист ручного ввода, «Пропуск» пишет `Entry.skip` за день, «Позже» откладывает на час. Использовать существующий планировщик и существующие обработчики действий уведомлений, а не заводить второй механизм.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/app && flutter test test/platform/`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/app/lib/state/sleep_reminder.dart \
        uhabits-flutter/app/lib/platform/flutter_alarm_scheduler.dart \
        uhabits-flutter/app/test/platform/sleep_reminder_test.dart
git commit -m "feat(sleep): утреннее напоминание

sleep.reminder#1 sleep.reminder#2 sleep.reminder#3"
```

---

### Task 17: Подсказки — пояс и цель

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_suggestions.dart`
- Modify: `uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/sleep/sleep_suggestions_test.dart`
- Test: `uhabits-flutter/app/test/ui/sleep/suggestions_test.dart`

**Interfaces:**
- Consumes: `SleepEpisode`, `SleepGoal`, `circularSpread`
- Produces: `TimezoneSkipSuggestion? suggestSkipForTimezone(Map<int, SleepEpisode>)`, `GoalSuggestion? suggestGoal(List<SleepEpisode>, SleepGoal)`

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  test('a two hour offset change raises a skip suggestion', () {
    final suggestion = suggestSkipForTimezone({
      8998: nightWithOffset(180),
      8999: nightWithOffset(180),
      9000: nightWithOffset(-60), // сдвиг на 4 часа
    });
    expect(suggestion, isNotNull, reason: 'sleep.skip#4');
    expect(suggestion!.fromDay, 9000, reason: 'sleep.skip#4');
  });

  test('an hour of offset change raises nothing', () {
    final suggestion = suggestSkipForTimezone({
      8999: nightWithOffset(180),
      9000: nightWithOffset(120),
    });
    expect(suggestion, isNull, reason: 'sleep.skip#4');
  });

  test('a goal suggestion needs ten nights out of fourteen', () {
    expect(suggestGoal(nightsShiftedBy(60, count: 9), goal), isNull,
        reason: 'sleep.suggest-goal#1');
    expect(suggestGoal(nightsShiftedBy(60, count: 10), goal), isNotNull,
        reason: 'sleep.suggest-goal#1');
  });

  test('a small median shift raises nothing', () {
    expect(suggestGoal(nightsShiftedBy(20, count: 14), goal), isNull,
        reason: 'sleep.suggest-goal#2');
  });

  test('a scattered schedule raises nothing even when shifted', () {
    // Сдвиг есть, но режима нет: подсказывать цель по хаосу бессмысленно.
    expect(suggestGoal(scatteredNights(count: 14), goal), isNull,
        reason: 'sleep.suggest-goal#3');
  });

  testWidgets('a suggestion never applies itself', (tester) async {
    final habit = await showScreenWithSuggestion();
    expect(habit.goal.bedMinutes, 1380, reason: 'sleep.suggest-goal#4');
    expect(find.textContaining('Подвинуть'), findsOneWidget,
        reason: 'sleep.suggest-goal#4');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/sleep/sleep_suggestions_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализовать**

Подсказка пропуска: смещение отличается от предыдущей ночи на 120 минут и более. Подсказка цели: не менее 10 ночей из 14, медианное круговое отклонение не менее 30 минут, круговой разброс не более 45 минут. Обе — только предложения; применение всегда через явное действие пользователя.

- [ ] **Step 4: Прогнать тесты**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test && cd ../../app && flutter test test/ui/sleep/`
Expected: PASS

- [ ] **Step 5: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/sleep/sleep_suggestions.dart \
        uhabits-flutter/packages/uhabits_core/test/sleep/sleep_suggestions_test.dart \
        uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart \
        uhabits-flutter/app/test/ui/sleep/suggestions_test.dart
git commit -m "feat(sleep): подсказки пропуска и цели

Расписание сна Apple недоступно через публичный API; подсказка цели по
фактическим данным даёт тот же практический эффект.

sleep.skip#4 sleep.skip#5 sleep.suggest-goal#1..#4"
```

---

### Task 18: Экспорт и записи о расхождениях

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/io/habit_list_csv_exporter.dart` (точное имя — по существующему файлу экспорта)
- Modify: `docs/parity/DEVIATIONS.md`
- Test: `uhabits-flutter/packages/uhabits_core/test/io/sleep_export_test.dart`

**Interfaces:**
- Consumes: `SleepSessionRepository`
- Produces: `SleepSessions.csv` в архиве экспорта

- [ ] **Step 1: Написать падающие тесты**

```dart
void main() {
  test('a sleep habit exports as numerical with percent values', () {
    final csv = exportHabits([sleepHabitWith(percent: 87)]);
    expect(csv, contains('SLEEP'), reason: 'sleep.export#1');
    expect(csv, contains('87'), reason: 'sleep.export#1');
  });

  test('nights go to their own file', () {
    final files = exportArchive([sleepHabitWithNights()]);
    expect(files.keys, contains('SleepSessions.csv'),
        reason: 'sleep.export#2');
    final rows = files['SleepSessions.csv']!.split('\n');
    expect(rows.first, contains('bed_start'), reason: 'sleep.export#2');
    expect(rows.first, contains('asleep_minutes'), reason: 'sleep.export#2');
  });

  test('exporting a database without sleep habits is unchanged', () {
    final files = exportArchive([plainBooleanHabit()]);
    expect(files.keys, isNot(contains('SleepSessions.csv')),
        reason: 'sleep.export#2');
  });
}
```

- [ ] **Step 2: Прогнать и убедиться в падении**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/io/sleep_export_test.dart`
Expected: FAIL.

- [ ] **Step 3: Реализовать экспорт**

Привычка со сном пишется в существующий формат как числовая, значения — проценты. Ночи выгружаются отдельным файлом с колонками таблицы. Файл появляется, только если в базе есть хотя бы одна привычка со сном: иначе экспорт обычной базы перестанет побайтово совпадать с тем, что даёт оригинал.

- [ ] **Step 4: Записать расхождения**

В `docs/parity/DEVIATIONS.md` добавить раздел «Расширения» с тремя записями, каждая с явным указанием влияния на пользователя:

```markdown
## Расширения

Ниже — сознательные отличия от Kotlin-оригинала, внесённые расширениями,
а не ошибки переноса.

### sleep: третье значение в habits.type
Оригинал знает только 0 и 1. База, содержащая привычку со сном, оригиналом
не откроется. Влияние на пользователя: откат на Kotlin-версию невозможен
после создания первой привычки со сном.

### sleep: схема выше версии 25
Миграции расширений начинаются со 100. Оригинал, увидев user_version 100,
попытается мигрировать вниз и откажется. Влияние на пользователя: то же.

### sleep: тип SLEEP в CSV-экспорте и файл SleepSessions.csv
Импорт такого архива в оригинал не поддерживается. Влияние на
пользователя: архив из этой версии читается только этой версией.
```

- [ ] **Step 5: Прогнать всё**

Run:
```bash
cd uhabits-flutter/packages/uhabits_core && dart test
cd ../../app && flutter test && flutter analyze
cd .. && tool/swift_widget_tests.sh
cd .. && dart uhabits-flutter/tool/parity_coverage.dart --verify
```
Expected: всё зелёное, паритетная проверка проходит.

- [ ] **Step 6: Закрыть правила в реестре расширений**

Run: `cd uhabits-flutter && dart tool/parity_coverage.dart --fully-cited`
Отметить `- [x]` только те фичи, у которых процитированы все правила. Правила, оказавшиеся неисполнимыми, записать в `DEVIATIONS.md`, а не тихо вычеркнуть.

- [ ] **Step 7: Коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/io/ \
        uhabits-flutter/packages/uhabits_core/test/io/sleep_export_test.dart \
        docs/parity/DEVIATIONS.md docs/extensions/SLEEP.md
git commit -m "feat(sleep): экспорт ночей и записи о расхождениях

sleep.export#1 sleep.export#2"
```

---

## Проверка на живом устройстве

После задачи 18 — не заменяет тесты, а ловит то, чего тесты не видят.

- [ ] Собрать релиз и поставить на телефон тем же путём, что использовался раньше: синхронизация в подписываемую копию, снятие App Group из обоих файлов entitlements, `flutter build ios --release`, `xcrun devicectl device install app`.
- [ ] Создать привычку со сном, дать доступ к Health, убедиться, что ночи за две недели подтянулись сами.
- [ ] Сверить процент одной ночи с расчётом вручную по таблицам из спецификации.
- [ ] Проверить экран во всех трёх темах — светлой, тёмной и истинно чёрной.
- [ ] Отказать в доступе к Health в системных настройках и убедиться, что экран остаётся рабочим.
- [ ] Ввести ночь вручную и убедиться, что она появилась в приложении «Здоровье».
