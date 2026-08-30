# Экран воздержания: уровень, который растёт — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Экран привычки-воздержания начинает показывать выдержанное время: уровень растёт с нуля, календарь разгорается вдоль серии, счётчик идёт до минут, а две бесполезные карточки уходят.

**Architecture:** Одна кривая роста (полураспад тридцать дней) питает три поверхности — кольцо, яркость календаря и оценку. Она живёт в `ScoreList` за необязательным параметром, выключенным для всех, кроме воздержания. Схема поднимается до 104 ради времени срыва. Длительность серии получает единое определение — прошедшие полные сутки — и одну функцию на все места, где показывается.

**Tech Stack:** Dart 3.11, Flutter, SQLite через `package:sqlite3`, портированное ядро в `packages/uhabits_core`.

**Spec:** `docs/superpowers/specs/2026-08-30-abstinence-screen-design.md`

## Global Constraints

- `docs/parity/FEATURES.md` не меняется ни одной строкой.
- Новые правила несут префикс `computed.` и живут в `docs/extensions/COMPUTED.md`; каждое процитировано тестом через `reason:`. `dart tool/parity_coverage.dart --verify` из `uhabits-flutter/` заканчивает с нулём нецитированных правил и нулём outstanding.
- Правка портированного кода идёт с записью в `docs/parity/DEVIATIONS.md`, прозой, в голосе соседей по разделу `## Расширения`, с указанием задетого паритетного правила.
- Всякая строка интерфейса заводится сразу в `app/lib/l10n/app_en.arb` **и** `app/lib/l10n/app_ru.arb`. Тест `every extension message is in Russian too` это требует.
- Русский текст читается вслух до коммита: строка не выбирает пол читателя и звучит как речь приложения, а не как перевод.
- Мутация засчитывается, только когда тест падает **на своём утверждении**, и падает именно тот тест, который называет правило. Мутации гоняются в отдельном worktree или rsync-копии, никогда в общем дереве. Откат — обратной заменой текста, никогда `git checkout`.
- `dart format` не запускается: принятое в репозитории форматирование старше нынешнего умолчания SDK.
- **Сон живёт на телефоне владельца.** Всякая задача, трогающая общий с ним код, доказывает, что он не сдвинулся.
- Один судья: срыв определяется `isAbstinenceLapse` и ничем иным.
- Коммиты — явным перечислением путей, никогда `git add -A`. Файл `app/ios/Runner.xcodeproj/project.pbxproj` содержит личный идентификатор подписи: не трогать, в коммиты не включать.

## Постановления, принятые при написании плана

**Отдельная карточка-счётчик воздержания складывается в Overview.** Спека даёт Overview счётчик, а он уже есть на своей карточке (`abstinence_section.dart`). Оставить обе значило бы показать одно число дважды в десяти сантиметрах друг от друга — ровно та беда, которую спека и чинит. Кнопка «Отметить срыв» переезжает вместе с числами: она единственный способ записать срыв с этого экрана, и потерять её нельзя.

**`daysWithoutLapse` не переписывается.** Задача 6 доказывает, что новая `elapsedDaysOf` на текущей серии даёт то же число, и обе остаются: одна отвечает про сегодня, вторая про любую серию.

---

### Task 1: Миграция 104 — журнал узнаёт время

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/database/extension_migrations.dart`
- Modify: `docs/extensions/COMPUTED.md`
- Test: `uhabits-flutter/packages/uhabits_core/test/database/extension_migrations_test.dart`

**Interfaces:**
- Consumes: карту `extensionMigrationSql` и константу `appDatabaseVersion` (сейчас 103).
- Produces: колонку `Lapses.at_millis`, `appDatabaseVersion == 104`.

- [ ] **Шаг 1: написать падающий тест**

В `test/database/extension_migrations_test.dart`, в конец файла перед закрывающей скобкой `main`:

```dart
  group('migration 104', () {
    test('the journal gains a column for the moment of the lapse', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);

      final List<String> columns = db.query<String>(
        "select name from pragma_table_info('Lapses')",
        const <String>[],
        (stmt) => stmt.getString(0),
      );

      expect(columns, contains('at_millis'),
          reason: 'computed.schema#8 — счётчик считает до минут, а день '
              'минут не содержит');
      expect(db.getVersion(), greaterThanOrEqualTo(104),
          reason: 'computed.schema#8');
    });

    test('a lapse that predates the column reads as no moment at all', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);
      db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
      db.run('insert into Lapses (habit, day, amount) values (1, 9000, 1)');

      expect(
        db.querySingle<int?>(
          'select at_millis from Lapses where habit = 1 and day = 9000',
          const <String>[],
          (stmt) => stmt.getIntOrNull(0),
        ),
        isNull,
        reason: 'computed.schema#9 — старая строка не выдумывает момент, '
            'которого в ней никогда не было',
      );
    });
  });
```

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/database/extension_migrations_test.dart`
Expected: FAIL — `Expected: contains 'at_millis'`.

- [ ] **Шаг 3: добавить миграцию**

В `extension_migrations.dart`, после блока `103:` и перед закрывающей `};`:

```dart
  104: r"""
alter table Lapses add column at_millis integer;""",
```

И заменить строку версии:

```dart
const int appDatabaseVersion = 104;
```

- [ ] **Шаг 4: дописать правила в реестр**

В `docs/extensions/COMPUTED.md`, в блок `computed.schema`, следующими номерами:

```markdown
8. `computed.schema#8` Журнал хранит момент срыва, а не только его день: счётчик воздержания идёт до минут, а в дне минут нет. Схема поднимается до 104.
9. `computed.schema#9` Момент необязателен. Строка, написанная до миграции или приехавшая из чужой копии, несёт `null` — и читается как отсутствие момента, а не как полночь.
```

- [ ] **Шаг 5: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/database/extension_migrations_test.dart`
Expected: PASS.

- [ ] **Шаг 6: мутация**

В rsync-копии дерева заменить `const int appDatabaseVersion = 104;` на `= 103;`.
Expected: падает `the journal gains a column for the moment of the lapse` на `Expected: contains 'at_millis'` — колонки нет, потому что миграция не проигрывается.
Откатить обратной заменой текста.

- [ ] **Шаг 7: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/database/extension_migrations.dart \
        uhabits-flutter/packages/uhabits_core/test/database/extension_migrations_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Give the lapse journal a moment, not just a day"
```

---

### Task 2: Репозиторий пишет и читает момент

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_repository.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/lapse_repository_test.dart`

**Interfaces:**
- Consumes: `Lapses.at_millis` (Задача 1).
- Produces:
  ```dart
  void LapseRepository.save(int habitId, int day,
      {int amount = LapseRepository.minimumAmount, int? atMillis});
  int? LapseRepository.momentOf(int habitId, int day);
  ```

- [ ] **Шаг 1: написать падающий тест**

В `test/computed/lapse_repository_test.dart`, перед закрывающей скобкой `main`:

```dart
  test('a lapse remembers the moment it happened', () {
    repository.save(1, 9000, amount: 1, atMillis: 1724832000000);

    expect(repository.momentOf(1, 9000), 1724832000000,
        reason: 'computed.schema#8 — момент возвращается тем же, каким его '
            'записали');
  });

  test('a lapse recorded without a moment has none', () {
    repository.save(1, 9000);

    expect(repository.momentOf(1, 9000), isNull,
        reason: 'computed.schema#9 — отсутствие момента есть null, а не ноль: '
            'ноль был бы полуночью первого января двухтысячного');
    expect(repository.forDay(1, 9000), LapseRepository.minimumAmount,
        reason: 'computed.lapses#2 — величина при этом записана обычным '
            'образом');
  });

  test('re-saving a day replaces its moment along with its amount', () {
    repository.save(1, 9000, amount: 1, atMillis: 1724832000000);
    repository.save(1, 9000, amount: 5, atMillis: 1724900000000);

    expect(repository.forDay(1, 9000), 5, reason: 'computed.lapses#3');
    expect(repository.momentOf(1, 9000), 1724900000000,
        reason: 'computed.schema#8 — правка дня переписывает и момент, иначе '
            'счётчик считал бы от стёртого срыва');
  });

  test('the moment of a day with no lapse is null', () {
    expect(repository.momentOf(1, 9000), isNull, reason: 'computed.lapses#1');
  });
```

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/lapse_repository_test.dart`
Expected: FAIL при компиляции — `No named parameter with the name 'atMillis'`.

- [ ] **Шаг 3: реализовать**

В `lapse_repository.dart` заменить тело `save` целиком:

```dart
  /// Записывает срыв величиной [amount] за [day], перезаписывая прежний.
  ///
  /// [atMillis] — момент срыва в миллисекундах эпохи, от которого считает
  /// счётчик воздержания. Необязателен: журнал знает дни с миграции 103, а
  /// моменты только со 104, и строка без момента — обычное дело
  /// (`computed.schema#9`). Перезапись дня меняет и момент: иначе счётчик
  /// считал бы от срыва, которого человек уже не помнит.
  void save(int habitId, int day,
      {int amount = minimumAmount, int? atMillis}) {
    if (amount < minimumAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'a lapse of nothing is silence, and silence is the absent row',
      );
    }
    _db.run(
      'insert into Lapses (habit, day, amount, at_millis) '
      'values (?, ?, ?, ?) '
      'on conflict(habit, day) do update set '
      'amount = excluded.amount, at_millis = excluded.at_millis',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, day);
        stmt.bindInt(3, amount);
        if (atMillis == null) {
          stmt.bindNull(4);
        } else {
          stmt.bindInt(4, atMillis);
        }
      },
    );
  }

  /// Момент срыва за [day] в миллисекундах эпохи, или null.
  ///
  /// Null отвечает на два разных вопроса одинаково — срыва в этот день не
  /// было, или он был записан до миграции 104, — и это намеренно: обе
  /// пустоты счётчик обрабатывает одним правилом (`computed.since#2`).
  int? momentOf(int habitId, int day) => _db.querySingle<int?>(
        'select at_millis from Lapses where habit = ? and day = ?',
        <String>['$habitId', '$day'],
        (stmt) => stmt.getIntOrNull(0),
      );
```

Сверить с существующим телом `save`, прежде чем заменять: подпись `_db.run` и способ привязки параметров берутся из него, а не из этого плана.

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/lapse_repository_test.dart`
Expected: PASS.

- [ ] **Шаг 5: мутации**

В rsync-копии, каждая отдельно, с откатом обратной заменой:

| мутация | падает |
|---|---|
| `at_millis = excluded.at_millis` убрать из `do update set` | `re-saving a day replaces its moment along with its amount` — `Expected: 1724900000000 Actual: 1724832000000` |
| `stmt.bindNull(4)` заменить на `stmt.bindInt(4, 0)` | `a lapse recorded without a moment has none` — `Expected: null Actual: <0>` |

- [ ] **Шаг 6: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_repository.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/lapse_repository_test.dart
git commit -m "Let the journal answer when, not only whether"
```

---

### Task 3: Момент переживает копию и экспорт

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_importer.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/io/habits_csv_exporter.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/io/lapse_import_test.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/io/lapse_export_test.dart`

**Interfaces:**
- Consumes: `LapseRepository.save(..., atMillis:)` и `momentOf` (Задача 2).
- Produces: колонку `Moment` в `Lapses.csv`; перенос момента при восстановлении копии.

- [ ] **Шаг 1: написать падающие тесты**

В `test/io/lapse_import_test.dart`, перед закрывающей скобкой `main`:

```dart
  test('a restored lapse keeps the moment it happened', () async {
    final LapseRepository origin = LapseRepository(source);
    origin.save(41, 8990, amount: 1, atMillis: 1724832000000);

    importer.importFor(sourceHabitId: 41, destinationHabitId: 7);

    expect(LapseRepository(destination).momentOf(7, 8990), 1724832000000,
        reason: 'computed.backup#6 — момент едет вместе со срывом, иначе '
            'после восстановления счётчик начал бы с полуночи');
  });

  test('a lapse with no moment restores without one', () async {
    LapseRepository(source).save(41, 8990);

    importer.importFor(sourceHabitId: 41, destinationHabitId: 7);

    expect(LapseRepository(destination).momentOf(7, 8990), isNull,
        reason: 'computed.backup#6 — пустота переносится пустотой, а не '
            'выдумывается на месте');
  });
```

В `test/io/lapse_export_test.dart` заменить утверждение о заголовке и строке в тесте `names its columns and writes one row per lapse`:

```dart
    expect(lines.first, 'Habit,Day,Moment,Amount',
        reason: 'computed.backup#5 — момент стоит рядом с днём, которому он '
            'принадлежит');
    expect(lines[1], 'Sober,2024-08-12,2024-08-12T09:20:00.000Z,45',
        reason: 'computed.backup#5');
```

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/io/lapse_import_test.dart test/io/lapse_export_test.dart`
Expected: FAIL — импорт возвращает `null` вместо момента; экспорт печатает старый заголовок.

- [ ] **Шаг 3: реализовать**

В `lapse_importer.dart`, в теле цикла, заменить вызов `save`:

```dart
      _destination.save(
        destinationHabitId,
        lapse.key,
        amount: lapse.value,
        atMillis: _origin.momentOf(sourceHabitId, lapse.key),
      );
```

В `habits_csv_exporter.dart`, в `_writeLapses`, заголовок и строку. Момент печатается как ISO-8601 в UTC, потому что он и хранится моментом, а не временем на часах; пустой момент даёт пустую ячейку:

```dart
    buffer.write('Habit${_delimiter}Day${_delimiter}Moment'
        '${_delimiter}Amount\n');
```

и в теле цикла, там где сейчас формируется строка:

```dart
      final int? moment = lapses.momentOf(habit.id!, day);
      final String at = moment == null
          ? ''
          : DateTime.fromMillisecondsSinceEpoch(moment, isUtc: true)
              .toIso8601String();
      buffer.write('${habit.name}$_delimiter${LocalDate(day).toCSVString()}'
          '$_delimiter$at$_delimiter$amount\n');
```

Прочитать `_writeLapses` целиком перед правкой: имена переменных и способ сборки строки берутся из него.

- [ ] **Шаг 4: дописать правило**

В `COMPUTED.md`, в блок `computed.backup`:

```markdown
6. `computed.backup#6` Момент срыва едет через восстановление копии вместе с ним. Пустота переносится пустотой: строка без момента остаётся строкой без момента, а не приобретает полночь.
```

И расширить текст `computed.backup#5`, дописав к перечислению колонок момент.

- [ ] **Шаг 5: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/io/`
Expected: PASS.

- [ ] **Шаг 6: мутации**

| мутация | падает |
|---|---|
| убрать `atMillis:` из вызова в импортёре | `a restored lapse keeps the moment it happened` — `Expected: 1724832000000 Actual: <null>` |
| `moment == null ? '' : ...` заменить на `'$moment'` | `names its columns and writes one row per lapse` — в строке окажется число миллисекунд вместо даты |

- [ ] **Шаг 7: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_importer.dart \
        uhabits-flutter/packages/uhabits_core/lib/src/io/habits_csv_exporter.dart \
        uhabits-flutter/packages/uhabits_core/test/io/lapse_import_test.dart \
        uhabits-flutter/packages/uhabits_core/test/io/lapse_export_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Carry the moment of a lapse out of the app and back in"
```

---

### Task 4: Кривая роста в `ScoreList`

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/models/score_list.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/lapse_score_test.dart`
- Modify: `docs/parity/DEVIATIONS.md`
- Modify: `docs/extensions/COMPUTED.md`

**Interfaces:**
- Consumes: `ScoreList.halvesOnLapse`, `Score.compute`.
- Produces: `int? ScoreList.growthHalfLifeDays` — поле экземпляра, по умолчанию `null`.

Это правка портированного кода. При `growthHalfLifeDays == null` весь портированный набор обязан пройти без единой правки — это и есть доказательство, что чужие привычки не задеты.

- [ ] **Шаг 1: написать падающие тесты**

В `test/computed/lapse_score_test.dart`, новой группой:

```dart
  group('computed.lapse-score growth', () {
    /// Уровень после [days] чистых дней подряд, с нуля.
    double levelAfter(int days, {int halfLife = 30}) {
      final FakeEntries entries = FakeEntries(<int, int>{});
      final ScoreList scores = ScoreList()
        ..halvesOnLapse = true
        ..growthHalfLifeDays = halfLife;
      scores.recompute(
        frequency: const Frequency(1, 1),
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 0.0,
        computedEntries: entries.getByInterval,
        from: getToday().minus(days - 1),
        to: getToday(),
      );
      return scores[getToday()].value;
    }

    test('#14 the level starts at nothing and climbs', () {
      expect(levelAfter(1), closeTo(0.0228, 0.0005),
          reason: 'computed.lapse-score#14 — первый день не даёт ста '
              'процентов: уровень зарабатывается, а не выдаётся');
      expect(levelAfter(30), closeTo(0.5, 0.005),
          reason: 'computed.lapse-score#14 — месяц есть половина');
      expect(levelAfter(100), closeTo(0.9, 0.005),
          reason: 'computed.lapse-score#14 — сто дней есть девяносто '
              'процентов');
    });

    test('#15 the half-life is the one the kind asks for', () {
      expect(levelAfter(13, halfLife: 13), closeTo(0.5, 0.005),
          reason: 'computed.lapse-score#15 — период берётся из поля, а не '
              'из портовой тринадцатки');
      expect(levelAfter(13, halfLife: 30), lessThan(0.3),
          reason: 'computed.lapse-score#15 — на тридцатидневном периоде те '
              'же тринадцать дней дают заметно меньше');
    });

    test('#16 a habit without the field keeps the port, to the last digit',
        () {
      final ScoreList ported = ScoreList();
      ported.recompute(
        frequency: const Frequency(1, 1),
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 0.0,
        computedEntries: FakeEntries(<int, int>{}).getByInterval,
        from: getToday().minus(29),
        to: getToday(),
      );

      expect(ported[getToday()].value, 1.0,
          reason: 'computed.lapse-score#16 — привычка «не больше» без '
              'кривой роста по-прежнему невиновна, пока не доказано');
    });
  });
```

Хелпер `FakeEntries` уже есть в этом файле — сверить его имя и конструктор перед написанием.

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/lapse_score_test.dart`
Expected: FAIL при компиляции — `The setter 'growthHalfLifeDays' isn't defined`.

- [ ] **Шаг 3: реализовать**

В `score_list.dart`, рядом с объявлением `halvesOnLapse`:

```dart
  /// Период полураспада кривой роста в днях, или null для портовой кривой.
  ///
  /// Расширение слоя вычисляемых привычек. При null всё в точности как в
  /// Kotlin: старт с единицы для привычки «не больше» и множитель из
  /// `Score.compute`. При заданном периоде уровень стартует с нуля и растёт
  /// своим множителем — это единственная форма, в которой «уровень
  /// сдержанности» вообще может расти (`computed.lapse-score#14`).
  ///
  /// Шаг остаётся портовым, аффинным. Именно поэтому «срыв делит пополам»
  /// продолжает работать: делить есть что.
  ///
  /// Ставит его `applyLapseScoring`, рядом с [halvesOnLapse].
  int? growthHalfLifeDays;
```

Заменить строку старта:

```dart
    final int? halfLife = growthHalfLifeDays;
    var previousValue =
        (isNumerical && isAtMost && halfLife == null) ? 1.0 : 0.0;
```

И развилку шага — ту, где сейчас `previousValue = Score.compute(...)` в ветви `else` после деления пополам:

```dart
          if (halvesOnLapse &&
              isAtMost &&
              frequency.denominator == 1 &&
              normalizedRollingSum > targetValue) {
            previousValue = previousValue / 2;
          } else if (halfLife != null) {
            // Тот же аффинный шаг, что у порта, но на своём множителе:
            // `Score.compute` считает его из частоты и портовой тринадцатки,
            // а воздержанию нужен свой период (`computed.lapse-score#15`).
            final double m = pow(0.5, 1.0 / halfLife).toDouble();
            previousValue =
                previousValue * m + percentageCompleted * (1 - m);
          } else {
            previousValue =
                Score.compute(freq, previousValue, percentageCompleted);
          }
```

- [ ] **Шаг 4: дописать правила**

В `COMPUTED.md`, в блок `computed.lapse-score`:

```markdown
14. `computed.lapse-score#14` Уровень воздержания растёт с нуля, а не выдаётся полным. Неделя даёт около пятнадцати процентов, месяц половину, сто дней девяносто.
15. `computed.lapse-score#15` Период полураспада кривой берётся у вида, а не у порта: воздержанию тридцать дней вместо портовых тринадцати. Шаг при этом остаётся портовым, аффинным, — иначе делить пополам было бы нечего.
16. `computed.lapse-score#16` Привычка без кривой роста считается ровно как в Kotlin: старт с единицы для «не больше», множитель из `Score.compute`. Портированный набор проходит без правок — это и есть проверка.
```

- [ ] **Шаг 5: отступление**

В `DEVIATIONS.md`, в раздел `## Расширения`, прозой в голосе соседей:

```markdown
### computed: уровень воздержания растёт с нуля

`ScoreList.recompute` для привычки «не больше» стартует с единицы —
`models.score-list-recompute-numerical-at-most#1`, «невиновен, пока не
доказано», — и портовый шаг тянет значение обратно к ней. Для привычки,
которую **делают**, это верно: не отмеченный день ничего не отнимает, пока не
доказано обратное.

Воздержание измеряет выдержанное время, и там это правило даёт бессмыслицу:
свежая привычка показывает сто процентов, а дальше только вниз. Уровень,
который нельзя заработать, ничего и не говорит.

Поэтому `ScoreList` получил `growthHalfLifeDays`, по умолчанию пустой. Когда
он задан, старт равен нулю, а множитель шага считается из него, а не из
частоты и портовой тринадцатки. Сам шаг остаётся портовым, аффинным, и это
не мелочь: решение «срыв делит оценку пополам» (`computed.lapse-score#1`)
работает только потому, что накопленное есть чему делить. Оценка как чистая
функция от длины серии была бы короче и обнуляла бы уровень при срыве —
то есть отменяла бы решение владельца молча.

Влияние на пользователя: none для привычек оригинала. Поле ставит только
`applyLapseScoring` и только виду `abstinence`; при пустом поле обе ветви
недостижимы, и весь портированный набор проходит без единой правки. Мутация
каждого умолчания роняет именно портированные тесты — это и есть проверка.
```

- [ ] **Шаг 6: прогнать оба набора**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test`
Expected: PASS, и число портированных тестов не изменилось — ни один не правился.

- [ ] **Шаг 7: мутации**

| мутация | падает |
|---|---|
| `halfLife == null` убрать из условия старта | `#16 a habit without the field keeps the port` — `Expected: 1.0 Actual: <0.0>` |
| `pow(0.5, 1.0 / halfLife)` заменить на `pow(0.5, 1.0 / 13)` | `#15 the half-life is the one the kind asks for` — тринадцать дней дадут половину там, где ожидается меньше трети |
| ветвь `else if (halfLife != null)` убрать целиком | `#14 the level starts at nothing and climbs` — уровень пойдёт портовой кривой и разойдётся на тридцатом дне |

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/models/score_list.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/lapse_score_test.dart \
        docs/extensions/COMPUTED.md docs/parity/DEVIATIONS.md
git commit -m "Let the level be earned instead of granted"
```

---

### Task 5: Включатель ставит период

**Files:**
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_scoring.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/lapse_scoring_test.dart`

**Interfaces:**
- Consumes: `ScoreList.growthHalfLifeDays` (Задача 4).
- Produces: `const int abstinenceHalfLifeDays = 30;` — экспортируемая константа.

- [ ] **Шаг 1: написать падающий тест**

В `test/computed/lapse_scoring_test.dart`:

```dart
  test('the switch sets the growth curve as well as the halving', () {
    final Habit habit = makeHabit();

    applyLapseScoring(habit, abstinenceDefinition);

    expect(habit.scores.growthHalfLifeDays, abstinenceHalfLifeDays,
        reason: 'computed.lapse-score#15 — деление пополам и рост включаются '
            'вместе: одно без другого не имеет смысла');
  });

  test('the switch clears the growth curve for every other kind', () {
    final Habit habit = makeHabit();
    applyLapseScoring(habit, abstinenceDefinition);

    applyLapseScoring(habit, sleepDefinition);

    expect(habit.scores.growthHalfLifeDays, isNull,
        reason: 'computed.lapse-score#16 — бывшее воздержание не остаётся с '
            'чужой кривой до перезапуска');
  });
```

Имена хелперов (`makeHabit`, `abstinenceDefinition`, `sleepDefinition`) взять из существующего файла — он уже проверяет `halvesOnLapse` в обе стороны.

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/lapse_scoring_test.dart`
Expected: FAIL — `Expected: <30> Actual: <null>`.

- [ ] **Шаг 3: реализовать**

В `lapse_scoring.dart`:

```dart
/// Период полураспада кривой роста воздержания, в днях.
///
/// Тридцать, а не портовые тринадцать: воздержание — длинная игра, и месяц
/// трезвости не должен выглядеть как «почти всё» (`computed.lapse-score#15`).
const int abstinenceHalfLifeDays = 30;
```

и в теле `applyLapseScoring`, перед `return`:

```dart
  habit.scores.growthHalfLifeDays = halves ? abstinenceHalfLifeDays : null;
```

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/`
Expected: PASS.

- [ ] **Шаг 5: мутация**

Заменить `halves ? abstinenceHalfLifeDays : null` на `abstinenceHalfLifeDays`.
Expected: падает `the switch clears the growth curve for every other kind` — `Expected: null Actual: <30>`.

- [ ] **Шаг 6: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/lapse_scoring.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/lapse_scoring_test.dart
git commit -m "Turn the growth curve on where the halving turns on"
```

---

### Task 6: Длительность серии — прошедшие полные сутки

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/computed/streak_duration.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/streak_duration_test.dart`
- Modify: `docs/extensions/COMPUTED.md`

**Interfaces:**
- Consumes: `Streak.start`, `Streak.end`, `Streak.length`, `getToday()`.
- Produces: `int elapsedDaysOf(Streak streak, {LocalDate? asOf})`.

- [ ] **Шаг 1: написать падающий тест**

Создать `test/computed/streak_duration_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  setUp(() => setToday(LocalDate(9000)));
  tearDown(resetToday);

  test('#8 a finished streak lasted as many days as it holds', () {
    // Серия с 8990 по 8999: срыв случился 9000-го, значит с начала до срыва
    // прошло ровно десять суток — столько же, сколько дней в серии.
    final Streak finished = Streak(LocalDate(8990), LocalDate(8999));

    expect(elapsedDaysOf(finished), 10,
        reason: 'computed.streak#8 — у завершённой серии включительный счёт '
            'и есть прошедшее время');
    expect(elapsedDaysOf(finished), finished.length,
        reason: 'computed.streak#8');
  });

  test('#8 the running streak has not lived through today yet', () {
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(running.length, 11,
        reason: 'портированный счёт включителен — это не меняется');
    expect(elapsedDaysOf(running), 10,
        reason: 'computed.streak#8 — сегодня ещё идёт, и целыми сутками не '
            'стало');
  });

  test('#8 a streak begun today has lasted no days at all', () {
    expect(elapsedDaysOf(Streak(LocalDate(9000), LocalDate(9000))), 0,
        reason: 'computed.streak#8 — первый день не превращается в единицу '
            'просто оттого, что начался');
  });

  test('#9 the running streak has not beaten an equal finished one', () {
    final Streak finished = Streak(LocalDate(8000), LocalDate(8010));
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(finished.length, running.length,
        reason: 'по включительному счёту они равны');
    expect(elapsedDaysOf(running), lessThan(elapsedDaysOf(finished)),
        reason: 'computed.streak#9 — идущая серия обходит завершённую только '
            'когда сегодняшний день закончится');
  });
}
```

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/streak_duration_test.dart`
Expected: FAIL — `Undefined name 'elapsedDaysOf'`.

- [ ] **Шаг 3: реализовать**

Создать `lib/src/computed/streak_duration.dart`:

```dart
import '../models/streak.dart';
import '../time/local_date.dart';

/// Сколько полных суток длится [streak] на день [asOf].
///
/// `Streak.length` считает дни включительно: серия с первого по пятнадцатое
/// есть пятнадцать дней. Для завершённой серии это и есть прошедшее время —
/// её конец есть последний чистый день, срыв случился на следующий, и с
/// начала до срыва прошло ровно столько суток, сколько дней в серии.
///
/// У идущей серии конец есть сегодня, и включительный счёт записывает
/// сегодняшний день целым, хотя он ещё идёт. Отсюда единое определение:
/// длительность есть прошедшие полные сутки (`computed.streak#8`).
///
/// Это не косметика. Идущая пятнадцатидневная серия не побила завершённую
/// пятнадцатидневную, пока сегодняшний день не закончился
/// (`computed.streak#9`).
///
/// Только для воздержания. Обычная привычка считает **сделанное**:
/// пятнадцать галочек есть пятнадцать, сегодняшняя в их числе. Счёт событий
/// включает сегодня; длительность — нет, пока день не кончился.
int elapsedDaysOf(Streak streak, {LocalDate? asOf}) {
  final LocalDate day = asOf ?? getToday();
  return streak.end.isOlderThan(day) ? streak.length : streak.length - 1;
}
```

Добавить экспорт в `lib/uhabits_core.dart`, в секцию `// Computed habits`, по алфавиту.

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/streak_duration_test.dart`
Expected: PASS.

- [ ] **Шаг 5: доказать согласие со счётчиком**

Дописать в тот же файл:

```dart
  test('#8 the running streak agrees with the days-without-a-lapse counter',
      () {
    final Streak running = Streak(LocalDate(8990), LocalDate(9000));

    expect(elapsedDaysOf(running), LocalDate(8990).daysUntil(LocalDate(9000)),
        reason: 'computed.streak#8 — счётчик и карточка серий считают одно, '
            'и это доказывается арифметикой, а не совпадением');
  });
```

- [ ] **Шаг 6: дописать правила**

```markdown
8. `computed.streak#8` Длительность серии есть прошедшие полные сутки. У завершённой серии это совпадает с включительным счётом порта, у идущей — на день меньше: сегодняшний день ещё не прожит.
9. `computed.streak#9` Идущая серия обходит равную ей завершённую только когда сегодняшний день закончится, а не в тот момент, когда начался.
```

- [ ] **Шаг 7: мутация**

Заменить `streak.end.isOlderThan(day)` на `true`.
Expected: падает `#8 the running streak has not lived through today yet` — `Expected: <10> Actual: <11>`.

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/streak_duration.dart \
        uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/streak_duration_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Measure a streak in days lived through, not days touched"
```

---

### Task 7: Текущая, лучшая и прошлая серии

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_streaks.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/abstinence_streaks_test.dart`
- Modify: `docs/extensions/COMPUTED.md`

**Interfaces:**
- Consumes: `elapsedDaysOf` (Задача 6), `StreakList.getBest`, `StreakList.getCurrent`, `daysWithoutLapse`.
- Produces:
  ```dart
  class AbstinenceStreaks {
    final int currentDays;
    final int? bestDays;
    final int? previousDays;
    bool get currentIsBest;
    double? get shareOfBest;
    double? get shareOfPrevious;
  }
  AbstinenceStreaks abstinenceStreaksOf(Habit habit, {LocalDate? asOf});
  ```

- [ ] **Шаг 1: написать падающий тест**

Создать `test/computed/abstinence_streaks_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  setUp(() => setToday(LocalDate(9000)));
  tearDown(resetToday);

  /// Привычка-воздержание с обязательством от [committedFrom] и срывами в
  /// перечисленные дни.
  Habit makeHabit({required int committedFrom, List<int> lapses = const []}) {
    final Habit habit = MemoryModelFactory().buildHabit()
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..frequency = const Frequency(1, 1)
      ..definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(),
      );
    for (final int day in lapses) {
      habit.originalEntries.add(Entry(LocalDate(day), 1000));
    }
    applyLapseScoring(habit, habit.definition);
    habit.recompute();
    return habit;
  }

  test('#10 with no lapse at all there is no record to compare against', () {
    final AbstinenceStreaks s =
        abstinenceStreaksOf(makeHabit(committedFrom: 8960));

    expect(s.currentDays, 40, reason: 'computed.streak#8');
    expect(s.currentIsBest, isTrue,
        reason: 'computed.streak#10 — первая же серия и есть лучшая');
    expect(s.previousDays, isNull,
        reason: 'computed.streak#10 — прошлой попытки не было, и выдумывать '
            'её нечем');
    expect(s.shareOfPrevious, isNull, reason: 'computed.streak#10');
  });

  test('#10 the current run is measured against the record and the last try',
      () {
    // Обязательство с 8960, срывы 8980 и 8985. Отсюда три серии:
    //   8960..8979 — завершённая, 20 прошедших суток;
    //   8981..8984 — завершённая, 4 суток;
    //   8986..9000 — идущая, включительно 15 дней, прошедших суток 14.
    final AbstinenceStreaks s = abstinenceStreaksOf(
        makeHabit(committedFrom: 8960, lapses: <int>[8980, 8985]));

    expect(s.currentDays, 14,
        reason: 'computed.streak#8 — сегодня ещё идёт и целыми сутками не '
            'стало');
    expect(s.bestDays, 20, reason: 'computed.streak#10');
    expect(s.previousDays, 4,
        reason: 'computed.streak#10 — прошлая есть предыдущая по времени, а '
            'не вторая по длине: двадцатидневная старше и длиннее, но между '
            'ней и нынешней была четырёхдневная');
    expect(s.currentIsBest, isFalse, reason: 'computed.streak#10');
    expect(s.shareOfBest, closeTo(0.7, 0.001), reason: 'computed.streak#10');
    expect(s.shareOfPrevious, closeTo(3.5, 0.001),
        reason: 'computed.streak#10 — прошлую попытку можно и перерасти, и '
            'доля тогда больше единицы');
  });

  test('#11 a lapse today leaves the counter at nothing', () {
    final AbstinenceStreaks s = abstinenceStreaksOf(
        makeHabit(committedFrom: 8960, lapses: <int>[9000]));

    expect(s.currentDays, 0,
        reason: 'computed.streak#11 — сорвался сегодня, значит не держится '
            'нисколько');
    expect(s.previousDays, 40,
        reason: 'computed.streak#11 — а прошлая серия есть та, что только что '
            'оборвалась');
  });
}
```

Сверить имена фабрики и хелперов с соседними тестами в `test/computed/` перед написанием.

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/abstinence_streaks_test.dart`
Expected: FAIL — `Undefined name 'abstinenceStreaksOf'`.

- [ ] **Шаг 3: реализовать**

Создать `lib/src/computed/abstinence_streaks.dart`:

```dart
import '../models/habit.dart';
import '../models/streak.dart';
import '../time/local_date.dart';
import 'days_without_lapse.dart';
import 'streak_duration.dart';

/// Предел, которым берётся весь список серий.
///
/// `StreakList.getBest` отдаёт `limit` самых длинных, отсортированных от
/// новой к старой. Своего «отдай все» у него нет — Kotlin наружу отдаёт
/// только лучшие, — поэтому предел берётся заведомо больше любого мыслимого
/// числа серий.
const int _allStreaks = 1 << 30;

/// Текущая серия воздержания в сравнении с лучшей и с прошлой.
///
/// Все три длины — в прошедших полных сутках (`computed.streak#8`), поэтому
/// число на карточке серий и число в счётчике совпадают по построению, а не
/// по совпадению.
class AbstinenceStreaks {
  const AbstinenceStreaks({
    required this.currentDays,
    required this.bestDays,
    required this.previousDays,
  });

  /// Сколько суток идёт нынешнее воздержание. Ноль, если сорвался сегодня.
  final int currentDays;

  /// Лучшая серия за всю историю привычки, или null, если серий нет вовсе.
  final int? bestDays;

  /// Серия, оборвавшаяся перед нынешней, или null для первой попытки.
  final int? previousDays;

  /// Нынешняя серия и есть рекорд.
  ///
  /// Показывается словом «рекорд» вместо ста процентов: сто процентов от
  /// самого себя — это не новость, а рекорд — новость.
  bool get currentIsBest => bestDays != null && currentDays >= bestDays!;

  /// Доля от рекорда, или null, когда сравнивать не с чем.
  double? get shareOfBest {
    final int? best = bestDays;
    if (best == null || best == 0) return null;
    return currentDays / best;
  }

  /// Доля от прошлой попытки. Больше единицы значит «уже дольше».
  double? get shareOfPrevious {
    final int? previous = previousDays;
    if (previous == null || previous == 0) return null;
    return currentDays / previous;
  }
}

/// Собирает три длины для привычки-воздержания.
AbstinenceStreaks abstinenceStreaksOf(Habit habit, {LocalDate? asOf}) {
  final LocalDate day = asOf ?? getToday();
  final List<Streak> newestFirst = habit.streaks.getBest(_allStreaks);
  final Streak? current = habit.streaks.getCurrent(day);

  // `getCurrent` отвечает null, когда сегодня в серию не входит — то есть
  // когда человек сорвался сегодня. Тогда прошлой считается самая новая
  // из списка: та, что только что оборвалась.
  final int skip = current == null ? 0 : 1;
  final Streak? previous =
      newestFirst.length > skip ? newestFirst[skip] : null;

  int? best;
  for (final Streak streak in newestFirst) {
    final int days = elapsedDaysOf(streak, asOf: day);
    if (best == null || days > best) best = days;
  }

  return AbstinenceStreaks(
    currentDays: daysWithoutLapse(habit, asOf: day),
    bestDays: best,
    previousDays: previous == null ? null : elapsedDaysOf(previous, asOf: day),
  );
}
```

Добавить экспорт в `lib/uhabits_core.dart` по алфавиту.

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/`
Expected: PASS.

- [ ] **Шаг 5: дописать правила**

```markdown
10. `computed.streak#10` Нынешняя серия сравнивается с лучшей за всю историю и с той, что оборвалась перед ней. Прошлая есть предыдущая по времени, а не вторая по длине. Первой попытке сравнивать не с чем, и она об этом молчит, а не показывает ноль.
11. `computed.streak#11` Срыв сегодня оставляет счётчик на нуле, а прошлой серией делает ту, что только что оборвалась.
```

- [ ] **Шаг 6: мутации**

| мутация | падает |
|---|---|
| `final int skip = current == null ? 0 : 1;` заменить на `= 1;` | `#11 a lapse today leaves the counter at nothing` — `previousDays` даст 0 вместо 40 |
| в цикле `best` заменить `elapsedDaysOf(streak, asOf: day)` на `streak.length` | `#10 the current run is measured against the record` — `Expected: <20> Actual: <21>` |

- [ ] **Шаг 7: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_streaks.dart \
        uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/abstinence_streaks_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Ask how this run compares to the record and to the last try"
```

---

### Task 8: Карточка серий показывает прошедшие сутки

**Files:**
- Modify: `uhabits-flutter/app/lib/state/show_habit_model.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/src/ui/screens/habits/show/views/streak_card.dart`
- Test: `uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart`
- Modify: `docs/parity/DEVIATIONS.md`

**Interfaces:**
- Consumes: `elapsedDaysOf` (Задача 6).
- Produces: `int Function(Streak)? lengthOf` — необязательный шов на `StreakCardState.buildState`, по умолчанию null.

Тот же приём, каким уже подаются `squareOf` и `intensityOf`: портированная арифметика не трогается, вид получает своё преобразование.

- [ ] **Шаг 1: написать падающий тест**

В `abstinence_screen_test.dart`:

```dart
  testWidgets('the best-streaks card counts days lived through',
      (tester) async {
    // Обязательство сорок дней назад, ни одного срыва: идёт сороковая сутки.
    await pumpAbstinenceScreen(tester, committedFrom: today - 40);

    expect(find.text('40'), findsWidgets,
        reason: 'computed.streak#8 — карточка серий говорит то же число, что '
            'счётчик над ней');
    expect(find.text('41'), findsNothing,
        reason: 'computed.streak#8 — включительный счёт остался порту');
  });
```

Хелпер `pumpAbstinenceScreen` уже есть в файле — сверить его подпись.

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/show/abstinence_screen_test.dart`
Expected: FAIL — `find.text('41')` находит карточку серий.

- [ ] **Шаг 3: реализовать**

В `streak_card.dart`, в `buildState`, добавить необязательный параметр и применить его там, где сейчас берётся длина серии:

```dart
  /// [lengthOf] не из порта: он отвечает, сколько дней показывать за серию.
  /// Null у всякой привычки, которую знает оригинал, и тогда длина берётся
  /// у самой серии, включительным счётом. Воздержание передаёт своё:
  /// длительность есть прошедшие полные сутки (`computed.streak#8`).
  static StreakCardState buildState({
    required Habit habit,
    required Theme theme,
    int Function(Streak)? lengthOf,
  }) {
```

Прочитать существующее тело `buildState` целиком и подставить `lengthOf` ровно там, где длина попадает в состояние.

В `show_habit_model.dart`, рядом с передачей `squareOf`:

```dart
      lengthOf: _abstinenceDefinition == null
          ? null
          : (Streak s) => elapsedDaysOf(s),
```

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/show/`
Expected: PASS.

- [ ] **Шаг 5: доказать, что сон не сдвинулся**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/ test/ui/habits/show/sleep_habit_screen_test.dart`
Expected: PASS, число тестов прежнее.

- [ ] **Шаг 6: отступление**

В `DEVIATIONS.md`:

```markdown
### computed: карточка серий воздержания считает прошедшие сутки

`Streak.length` считает дни включительно (`models.streak-computation#1`), и
для привычки оригинала это верно: пятнадцать галочек есть пятнадцать,
сегодняшняя в их числе. Счёт событий включает сегодня.

Воздержание измеряет выдержанное время, а сегодняшний день ещё идёт.
Поэтому карточка получает для него преобразование длины — прошедшие полные
сутки (`computed.streak#8`). У завершённой серии оно ничего не меняет: её
конец есть последний чистый день, срыв случился на следующий, и включительный
счёт там и есть прошедшее время. Меняется только идущая серия, и на день.

Влияние на пользователя: none для привычек оригинала — шов пустой, длина
берётся у самой серии. Для воздержания счётчик и карточка перестают
показывать два разных числа в паре сантиметров друг от друга.
```

- [ ] **Шаг 7: мутация**

Убрать `lengthOf:` из вызова в `show_habit_model.dart`.
Expected: падает `the best-streaks card counts days lived through` — находится «41».

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/ui/screens/habits/show/views/streak_card.dart \
        uhabits-flutter/app/lib/state/show_habit_model.dart \
        uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart \
        docs/parity/DEVIATIONS.md
git commit -m "Make the streak card and the counter say one number"
```

---

### Task 9: Момент, с которого идёт воздержание

**Files:**
- Create: `uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_since.dart`
- Modify: `uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart`
- Test: `uhabits-flutter/packages/uhabits_core/test/computed/abstinence_since_test.dart`
- Modify: `docs/extensions/COMPUTED.md`

**Interfaces:**
- Consumes: `LapseRepository.momentOf` (Задача 2), `StreakList.getCurrent`, `utcInstantOfLocal` из `sleep/local_instant.dart`.
- Produces: `int? abstinenceSinceMillis(Habit habit, LapseRepository lapses, {LocalDate? asOf})`.

- [ ] **Шаг 1: написать падающий тест**

Создать `test/computed/abstinence_since_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  setUp(() {
    setToday(LocalDate(9000));
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
  });
  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  test('#1 the count starts at the moment of the last lapse', () {
    // Срыв 8995-го в 14:30 UTC.
    const int at = (8995 + 10957) * 86400000 + 14 * 3600000 + 30 * 60000;
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);
    lapses.save(habit.id!, 8995, amount: 1, atMillis: at);

    expect(abstinenceSinceMillis(habit, lapses), at,
        reason: 'computed.since#1 — считаем от того мгновения, когда сорвался');
  });

  test('#2 a lapse with no moment counts from the midnight after it', () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);

    expect(abstinenceSinceMillis(habit, lapses),
        (8996 + 10957) * 86400000,
        reason: 'computed.since#2 — полночь ПОСЛЕ дня срыва: первый момент, '
            'про который точно известно, что он был чистым');
  });

  test('#3 with no lapse at all the count starts at the commitment', () {
    final habit = makeAbstinence(committedFrom: 8960);

    expect(abstinenceSinceMillis(habit, lapses), (8960 + 10957) * 86400000,
        reason: 'computed.since#3 — день, который человек выбрал сам, с его '
            'полуночи');
  });

  test('#4 a lapse today means the count has not started', () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[9000]);

    expect(abstinenceSinceMillis(habit, lapses), isNull,
        reason: 'computed.since#4 — сорвался сегодня, считать нечего');
  });
}
```

Хелперы `makeAbstinence` и `lapses` собрать в файле по образцу `abstinence_sync_test.dart` — он уже открывает базу в памяти и строит привычку-воздержание.

- [ ] **Шаг 2: прогнать и увидеть падение**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/abstinence_since_test.dart`
Expected: FAIL — `Undefined name 'abstinenceSinceMillis'`.

- [ ] **Шаг 3: реализовать**

Создать `lib/src/computed/abstinence_since.dart`:

```dart
import '../models/habit.dart';
import '../models/streak.dart';
import '../sleep/local_instant.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';
import 'lapse_repository.dart';

/// Мгновение, с которого идёт нынешнее воздержание, в миллисекундах эпохи.
///
/// Null, когда воздержание не идёт: человек сорвался сегодня
/// (`computed.since#4`).
///
/// Правило одно, и оно короче, чем кажется. Серия начинается на следующий
/// день после срыва, значит срыв лежит на дне `start - 1`:
///
///  * момент этого срыва известен — считаем от него (`computed.since#1`);
///  * момента нет, потому что строка старше миграции 104 или приехала из
///    чужой копии — считаем от полуночи дня `start`, то есть от полуночи
///    ПОСЛЕ дня срыва: это первый момент, про который точно известно, что он
///    был чистым (`computed.since#2`);
///  * срыва там нет вовсе, потому что серия началась с обязательства —
///    считаем от полуночи дня `start` (`computed.since#3`).
///
/// Две последние ветви дают один и тот же ответ, поэтому в коде их одна.
int? abstinenceSinceMillis(
  Habit habit,
  LapseRepository lapses, {
  LocalDate? asOf,
}) {
  final LocalDate day = asOf ?? getToday();
  final Streak? current = habit.streaks.getCurrent(day);
  if (current == null) return null;

  final int? id = habit.id;
  if (id != null) {
    final int? at = lapses.momentOf(id, current.start.daysSince2000 - 1);
    if (at != null) return at;
  }

  // Полночь дня начала серии, в зоне человека: счётчик показывает
  // длительность, и час её начала должен быть тем же часом, каким человек
  // видит смену суток.
  return utcInstantOfLocal(
    current.start.daysSince2000 * DateUtils.dayLength,
    getDefaultTimeZone(),
  );
}
```

Сверить имя и подпись `utcInstantOfLocal`, а также имя константы длины суток, с `sleep/local_instant.dart` и `time/date_utils.dart`: если аргументы там другие, брать оттуда, а не отсюда.

Добавить экспорт в `lib/uhabits_core.dart` по алфавиту.

- [ ] **Шаг 4: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/packages/uhabits_core && dart test test/computed/abstinence_since_test.dart`
Expected: PASS.

- [ ] **Шаг 5: прогнать в чужой зоне**

Run: `cd uhabits-flutter/packages/uhabits_core && TZ=Pacific/Kiritimati dart test test/computed/abstinence_since_test.dart`
Expected: PASS. Зона в тесте прибита, и результат не зависит от того, где стоит машина.

- [ ] **Шаг 6: дописать правила**

```markdown
- [ ] `computed.since`
1. `computed.since#1` Счётчик считает от мгновения последнего срыва, когда оно известно.
2. `computed.since#2` Когда мгновения нет — строка старше миграции 104 или приехала из чужой копии, — счёт идёт от полуночи после дня срыва: первого момента, про который точно известно, что он был чистым.
3. `computed.since#3` Когда срывов не было вовсе, счёт идёт от полуночи первого дня текущей серии — у привычки с днём обязательства это он и есть.
4. `computed.since#4` Срыв сегодня означает, что воздержание не идёт: счётчику нечего показывать.
```

Раздел заводится невзведённым (`- [ ]`); взводит его Задача 16.

- [ ] **Шаг 7: мутации**

| мутация | падает |
|---|---|
| `current.start.daysSince2000 - 1` заменить на `current.start.daysSince2000` | `#1 the count starts at the moment of the last lapse` — момент не найдётся, вернётся полночь |
| `if (current == null) return null;` убрать | `#4 a lapse today means the count has not started` — падение по null вместо ожидаемого null; **переписать мутацию** на `if (current == null) return 0;`, тогда падает утверждение |

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/packages/uhabits_core/lib/src/computed/abstinence_since.dart \
        uhabits-flutter/packages/uhabits_core/lib/uhabits_core.dart \
        uhabits-flutter/packages/uhabits_core/test/computed/abstinence_since_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Answer the moment this stretch of abstinence began"
```

---

### Task 10: Длительность словами

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_duration.dart`
- Modify: `uhabits-flutter/app/lib/l10n/app_en.arb`, `uhabits-flutter/app/lib/l10n/app_ru.arb`
- Modify: `uhabits-flutter/app/test/l10n/localization_inventory_test.dart`
- Test: `uhabits-flutter/app/test/ui/habits/abstinence/abstinence_duration_test.dart`

**Interfaces:**
- Produces: `String formatAbstinenceDuration(L10n l10n, DateTime from, DateTime to)`.

- [ ] **Шаг 1: завести строки**

В `app_en.arb` и `app_ru.arb`, пять множественных форм:

```json
  "durationYears": "{count, plural, =1{{count} year} other{{count} years}}",
  "durationMonths": "{count, plural, =1{{count} month} other{{count} months}}",
  "durationDays": "{count, plural, =1{{count} day} other{{count} days}}",
  "durationHours": "{count, plural, =1{{count} hour} other{{count} hours}}",
  "durationMinutes": "{count, plural, =1{{count} minute} other{{count} minutes}}",
```

Русские, со всеми формами:

```json
  "durationYears": "{count, plural, one{{count} год} few{{count} года} many{{count} лет} other{{count} года}}",
  "durationMonths": "{count, plural, one{{count} месяц} few{{count} месяца} many{{count} месяцев} other{{count} месяца}}",
  "durationDays": "{count, plural, one{{count} день} few{{count} дня} many{{count} дней} other{{count} дня}}",
  "durationHours": "{count, plural, one{{count} час} few{{count} часа} many{{count} часов} other{{count} часа}}",
  "durationMinutes": "{count, plural, one{{count} минута} few{{count} минуты} many{{count} минут} other{{count} минуты}}",
```

Поднять литерал числа строк расширения в `localization_inventory_test.dart` на пять и пересчитать его по фактическому числу ключей, а не по этому плану.

Перегенерировать: `cd uhabits-flutter/app && flutter gen-l10n`.

- [ ] **Шаг 2: написать падающий тест**

Создать `test/ui/habits/abstinence/abstinence_duration_test.dart`:

```dart
  /// Начало отсчёта во всех тестах, кроме календарного.
  final DateTime start = DateTime(2026, 8, 1, 9, 0);

  /// [formatAbstinenceDuration] с русской локалью, от [start] на [held] вперёд.
  String after(Duration held) =>
      formatAbstinenceDuration(ru, start, start.add(held));

  test('three most significant units, and no more', () {
    expect(after(const Duration(days: 14, hours: 6, minutes: 12)),
        '14 дней 6 часов 12 минут',
        reason: 'computed.since#5 — три старшие единицы читаются, пять — нет');
  });

  test('a unit that is zero is skipped, not printed', () {
    expect(after(const Duration(hours: 6, minutes: 12)), '6 часов 12 минут',
        reason: 'computed.since#5 — «0 дней 6 часов» есть шум');
  });

  test('the first minutes are still an answer', () {
    expect(after(const Duration(minutes: 3)), '3 минуты',
        reason: 'computed.since#5 — счётчик отвечает с первой минуты, а не с '
            'первого дня');
    expect(after(Duration.zero), '0 минут',
        reason: 'computed.since#5 — и в самое первое мгновение тоже');
  });

  test('years and months come from the calendar, not from averages', () {
    // С 12 августа 2024 по 30 августа 2026: два года и восемнадцать дней.
    // Месяцев ровно ноль, и они обязаны пропасть, а не занять место в тройке.
    expect(
      formatAbstinenceDuration(
          ru, DateTime(2024, 8, 12), DateTime(2026, 8, 30)),
      '2 года 18 дней',
      reason: 'computed.since#6 — месяцы разной длины, и «тридцать дней в '
          'месяце» соврало бы на две недели за год',
    );
  });

  test('a month is a month even when it is twenty-eight days', () {
    // С 31 января по 1 марта невисокосного года: месяц и один день.
    expect(
      formatAbstinenceDuration(ru, DateTime(2026, 1, 31), DateTime(2026, 3, 1)),
      '1 месяц 1 день',
      reason: 'computed.since#6 — февраль короче тридцати дней, и календарный '
          'перенос это знает',
    );
  });
```

Хелпер `ru` — экземпляр `L10n` русской локали; в наборе приложения такие уже строятся, взять оттуда.

- [ ] **Шаг 3: прогнать и увидеть падение**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/abstinence/abstinence_duration_test.dart`
Expected: FAIL — `Undefined name 'formatAbstinenceDuration'`.

- [ ] **Шаг 4: реализовать**

Создать `abstinence_duration.dart`:

```dart
import '../../../l10n/app_localizations.dart';

/// Сколько единиц времени показывает счётчик.
///
/// Три: «14 дней 6 часов 12 минут» читается, «1 год 2 месяца 14 дней 6 часов
/// 12 минут» — уже нет (`computed.since#5`).
const int _unitsShown = 3;

/// Длительность воздержания словами, тремя старшими ненулевыми единицами.
///
/// Берёт два мгновения, а не длительность: годы и месяцы считаются
/// календарно, и без даты начала их не посчитать. Месяцы разной длины, и
/// усреднение соврало бы на две недели за год (`computed.since#6`).
///
/// Оба мгновения обязаны быть в одной зоне: вызывающий строит их из
/// `abstinenceSinceMillis` и текущего времени, оба местные.
///
/// Нулевые единицы пропускаются целиком, а не занимают место: «2 года
/// 18 дней», а не «2 года 0 месяцев 18 дней». Ноль ничего не сообщает, но
/// вытесняет из тройки то, что сообщает.
/// [from], сдвинутое на [totalMonths] месяцев вперёд, с зажимом дня.
///
/// Зажим обязателен. `DateTime(2026, 2, 31)` Dart нормализует в третье марта,
/// и без зажима у всякого, кто сорвался тридцать первого числа, счётчик
/// уезжал бы на несколько дней в короткие месяцы. Тридцать первое января плюс
/// месяц — это двадцать восьмое февраля, а не третье марта.
DateTime _shiftMonths(DateTime from, int totalMonths) {
  final int raw = from.month - 1 + totalMonths;
  final int year = from.year + (raw ~/ 12);
  final int month = raw % 12 + 1;
  // Нулевой день следующего месяца есть последний день этого.
  final int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    from.day < lastDay ? from.day : lastDay,
    from.hour,
    from.minute,
    from.second,
  );
}

String formatAbstinenceDuration(L10n l10n, DateTime from, DateTime to) {
  if (!to.isAfter(from)) return l10n.durationMinutes(0);

  // Сколько целых месяцев уместилось: берём оценку сверху и убавляем, пока
  // перенос обгоняет настоящее. Цикл делает один-два шага.
  int totalMonths = (to.year - from.year) * 12 + (to.month - from.month) + 1;
  while (totalMonths > 0 && _shiftMonths(from, totalMonths).isAfter(to)) {
    totalMonths -= 1;
  }

  final int years = totalMonths ~/ 12;
  final int months = totalMonths % 12;
  final Duration rest = to.difference(_shiftMonths(from, totalMonths));

  final List<String> parts = <String>[];
  void add(int value, String Function(int) word) {
    if (value > 0 && parts.length < _unitsShown) parts.add(word(value));
  }

  add(years, l10n.durationYears);
  add(months, l10n.durationMonths);
  add(rest.inDays, l10n.durationDays);
  add(rest.inHours.remainder(24), l10n.durationHours);
  add(rest.inMinutes.remainder(60), l10n.durationMinutes);

  // Первая минута воздержания — тоже ответ, и он не должен быть пустым.
  if (parts.isEmpty) return l10n.durationMinutes(0);
  return parts.join(' ');
}
```

Проверить на тесте с двумя годами и восемнадцатью днями: месяцев там ноль, и правило «пропускать нулевые» обязано пропустить их так, чтобы дни попали в тройку. Если написать «печатать, когда старшая уже напечатана», тест упадёт с `Actual: '2 года 0 месяцев 18 дней'` — именно поэтому он в наборе есть.

- [ ] **Шаг 5: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/abstinence/ test/l10n/`
Expected: PASS.

- [ ] **Шаг 6: дописать правила**

```markdown
5. `computed.since#5` Счётчик показывает три старшие ненулевые единицы и отвечает с первой минуты, а не с первого дня.
6. `computed.since#6` Годы и месяцы считаются календарно от начального мгновения: месяцы разной длины, и усреднение соврало бы на недели.
```

- [ ] **Шаг 7: мутация**

Ограничить сборку двумя единицами вместо трёх.
Expected: падает `three most significant units, and no more` — `Actual: '14 дней 6 часов'`.

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_duration.dart \
        uhabits-flutter/app/lib/l10n/ \
        uhabits-flutter/app/test/ui/habits/abstinence/abstinence_duration_test.dart \
        uhabits-flutter/app/test/l10n/localization_inventory_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Say a duration the way a person says it"
```

---

### Task 11: Overview воздержания

**Files:**
- Create: `uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_overview.dart`
- Modify: `uhabits-flutter/app/lib/l10n/app_en.arb`, `uhabits-flutter/app/lib/l10n/app_ru.arb`
- Test: `uhabits-flutter/app/test/ui/habits/abstinence/abstinence_overview_test.dart`

**Interfaces:**
- Consumes: `AbstinenceStreaks` (Задача 7), `abstinenceSinceMillis` (Задача 9), `formatAbstinenceDuration` (Задача 10), `RingView` из `app/lib/ui/common/views/ring_view.dart`.
- Produces: виджет `AbstinenceOverviewCard`.

Карточка несёт счётчик, кольцо, два отношения, число срывов и кнопку «Отметить срыв» — кнопка переезжает сюда из `abstinence_section.dart`, которая после Задачи 12 исчезает.

- [ ] **Шаг 1: завести строки**

```json
  "abstinenceOfRecord": "of the record",
  "abstinenceOfPrevious": "of the previous run",
  "abstinenceIsRecord": "record",
  "abstinenceLapsesTotal": "lapses"
```

Русские: `«от рекорда»`, `«от прошлой серии»`, `«рекорд»`, `«срывов»`.

- [ ] **Шаг 2: написать падающий тест**

```dart
  testWidgets('the counter, the ring and the two shares', (tester) async {
    await pumpOverview(tester, committedFrom: today - 40, lapses: const []);

    expect(find.text('40 дней'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — счётчик крупно и сверху');
    expect(find.byType(RingView), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — уровень кольцом');
    expect(find.text('рекорд'), findsOneWidget,
        reason: 'computed.streak#10 — сто процентов от самого себя не новость, '
            'а рекорд — новость');
    expect(find.text('от прошлой серии'), findsNothing,
        reason: 'computed.streak#10 — первой попытке сравнивать не с чем, и '
            'строка не рисуется вовсе');
  });

  testWidgets('the shares appear once there is something to compare with',
      (tester) async {
    await pumpOverview(tester,
        committedFrom: today - 40, lapses: <int>[today - 20, today - 10]);

    expect(find.textContaining('от рекорда'), findsOneWidget,
        reason: 'computed.streak#10');
    expect(find.textContaining('от прошлой серии'), findsOneWidget,
        reason: 'computed.streak#10');
  });

  testWidgets('the button is here, because it has nowhere else to be',
      (tester) async {
    await pumpOverview(tester, committedFrom: today - 40, lapses: const []);

    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — жест переехал вместе с '
            'числами, а не потерялся между ними');
  });
```

- [ ] **Шаг 3: прогнать и увидеть падение**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/abstinence/abstinence_overview_test.dart`
Expected: FAIL — `Undefined name 'AbstinenceOverviewCard'`.

- [ ] **Шаг 4: реализовать**

Создать `abstinence_overview.dart`. Карточка — обычный `StatelessWidget`,
собирается из готовых частей и своей арифметики не заводит:

```dart
class AbstinenceOverviewCard extends StatelessWidget {
  const AbstinenceOverviewCard({
    required this.habit,
    required this.definition,
    required this.scope,
    required this.onLapse,
    super.key,
  });

  final core.Habit habit;
  final core.HabitDefinition definition;
  final AppScope scope;
  final Future<void> Function() onLapse;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final core.Theme theme = coreThemeOf(context);
    final core.AbstinenceStreaks streaks = core.abstinenceStreaksOf(habit);
    final int? since = core.abstinenceSinceMillis(habit, scope.lapses);
    final double level = habit.scores[core.getToday()].value;

    return CardBox(
      title: l10n.overview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Счётчик крупно и сверху: это ответ на вопрос, ради которого
          // экран открывают (`computed.abstinence-screen#11`).
          Text(
            since == null
                ? l10n.durationMinutes(0)
                : formatAbstinenceDuration(
                    l10n,
                    DateTime.fromMillisecondsSinceEpoch(since),
                    DateTime.now(),
                  ),
            key: counterKey,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: RingView(
                  percentage: level,
                  color: _toFlutterColor(theme.colorOf(habit.color)),
                  backgroundColor: _toFlutterColor(theme.cardBgColor),
                  inactiveColor: _toFlutterColor(theme.lowContrastTextColor),
                  text: '${(level * 100).round()}%',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Сто процентов от самого себя — не новость; рекорд —
                    // новость (`computed.streak#10`).
                    _shareLine(
                      context,
                      label: l10n.abstinenceOfRecord,
                      share: streaks.currentIsBest ? null : streaks.shareOfBest,
                      instead: streaks.currentIsBest
                          ? l10n.abstinenceIsRecord
                          : null,
                    ),
                    // Первой попытке сравнивать не с чем, и строки нет вовсе.
                    if (streaks.shareOfPrevious != null)
                      _shareLine(
                        context,
                        label: l10n.abstinenceOfPrevious,
                        share: streaks.shareOfPrevious,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AbstinenceLapseButton(habit: habit, onLapse: onLapse),
        ],
      ),
    );
  }
}
```

`CardBox`, `_toFlutterColor` и `AbstinenceLapseButton` — существующие части:
первые две взять у соседних карточек, кнопку — из удаляемой в Задаче 12
`abstinence_section.dart`, перенеся её вместе с тестами. `_shareLine` —
приватный хелпер этого файла: подпись, число процентов и слово вместо числа,
когда доля не считается.

- [ ] **Шаг 5: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/abstinence/`

- [ ] **Шаг 6: дописать правило**

```markdown
11. `computed.abstinence-screen#11` Overview воздержания несёт счётчик, кольцо уровня, долю от рекорда и долю от прошлой серии. Числа берутся из тех же функций, что питают карточку серий, поэтому согласованы по построению, а не по совпадению.
```

- [ ] **Шаг 7: мутация**

Заменить `streaks.shareOfBest` на долю, считанную от `streak.length`.
Expected: падает `the shares appear once there is something to compare with` — доля разойдётся с карточкой серий на один день.

- [ ] **Шаг 8: коммит**

```bash
git add uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_overview.dart \
        uhabits-flutter/app/lib/l10n/ \
        uhabits-flutter/app/test/ui/habits/abstinence/abstinence_overview_test.dart \
        docs/extensions/COMPUTED.md
git commit -m "Give the overview the numbers a person opens it for"
```

---

### Task 12: Overview встаёт на экран, старая карточка уходит

**Files:**
- Modify: `uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Delete: `uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_section.dart`
- Delete: `uhabits-flutter/app/lib/ui/habits/abstinence/abstinence_counter.dart`
- Test: `uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart`

**Interfaces:**
- Consumes: `AbstinenceOverviewCard` (Задача 11).

- [ ] **Шаг 1: написать падающий тест**

```dart
  testWidgets('the counter shows once, and it shows in the overview',
      (tester) async {
    await pumpAbstinenceScreen(tester, committedFrom: today - 40);

    expect(find.text('40 дней'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — одно число в одном месте');
    expect(
      tester.getRect(find.byType(AbstinenceOverviewCard)).top,
      lessThan(tester.getRect(find.byKey(ShowHabitScreen.cardKey(
              ShowHabitCard.score)))
          .top),
      reason: 'computed.abstinence-screen#3 — Overview стоит в том же шве, '
          'что и блоки сна',
    );
  });
```

- [ ] **Шаг 2: прогнать, увидеть падение**

Expected: FAIL — счётчик находится дважды.

- [ ] **Шаг 3: реализовать**

В `show_habit_screen.dart`, в `_buildCard`, ветвь `ShowHabitCard.overview`:

```dart
      case ShowHabitCard.overview:
        final core.HabitDefinition? abstinence = _abstinenceDefinition;
        if (abstinence != null) {
          return AbstinenceOverviewCard(
            key: key,
            habit: widget.habit,
            definition: abstinence,
            scope: widget.scope,
            onLapse: _repaintComputed,
          );
        }
        // дальше — существующая портированная ветвь, без изменений
```

Из `_buildColumn` убрать вызов `buildAbstinenceSection`: своих блоков у
воздержания больше нет, всё живёт в Overview, а Overview стоит в шве и так.

Удалить `abstinence_section.dart` и `abstinence_counter.dart` вместе с их
тестами. Утверждения из тех тестов, которые проверяли поведение, а не
расположение, — про подпись «Последний срыв», про кнопку, про согласие трёх
поверхностей при допуске тридцать — перенести в
`abstinence_overview_test.dart`, не ослабляя ни одного. Перенос проверяется
счётом: сколько утверждений ушло из удаляемых файлов, столько обязано
прибавиться в целевом.

- [ ] **Шаг 4: прогнать оба набора**

Run: `cd uhabits-flutter/app && flutter analyze && flutter test`

- [ ] **Шаг 5: коммит**

```bash
git add -u uhabits-flutter/app/lib/ui/habits/abstinence/ \
       uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart \
       uhabits-flutter/app/test/
git commit -m "Show the counter once, where a person looks for it"
```

---

### Task 13: Цель в подписи

**Files:**
- Modify: `uhabits-flutter/app/lib/ui/habits/show/cards/subtitle_card_view.dart`
- Modify: `uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Modify: `uhabits-flutter/app/lib/l10n/app_en.arb`, `uhabits-flutter/app/lib/l10n/app_ru.arb`
- Test: `uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart`

**Interfaces:**
- Consumes: `SubtitleCardView.targetOverride`.
- Produces: `String? targetIconOverride`, `bool showsFrequency` на `SubtitleCardView`.

- [ ] **Шаг 1: завести строку**

```json
  "abstinenceGoalNever": "Not once"
```
Русская: `«Ни разу»`.

При ненулевом допуске берётся уже существующая строка вопроса о величине — та же формулировка, что человек видел, когда его спрашивали «сколько».

- [ ] **Шаг 2: написать падающий тест**

```dart
  testWidgets('the goal says what is promised, not which way the arrow points',
      (tester) async {
    await pumpAbstinenceScreen(tester, committedFrom: today - 40);

    expect(find.text('Ни разу'), findsOneWidget,
        reason: 'computed.abstinence-screen#12 — обещание словами');
    expect(find.text('Каждый день'), findsNothing,
        reason: 'computed.abstinence-screen#12 — частота у воздержания есть '
            'подробность устройства, а не цель');
  });

  testWidgets('an allowance is quoted the way it was asked', (tester) async {
    await pumpAbstinenceScreen(tester,
        committedFrom: today - 40, allowance: 30, unit: 'минут');

    expect(find.text('Не более 30 минут в день'), findsOneWidget,
        reason: 'computed.abstinence-screen#12 — одна формулировка, один '
            'смысл: та же фраза стоит в вопросе о величине');
  });
```

- [ ] **Шаг 3: прогнать и увидеть падение**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/show/abstinence_screen_test.dart`
Expected: FAIL — на экране «Каждый день» и портированный текст цели.

- [ ] **Шаг 4: реализовать**

В `subtitle_card_view.dart` добавить два поля рядом с существующим
`targetOverride`:

```dart
  /// Значок вместо портированного, когда обещание рисуется не стрелкой.
  ///
  /// Стрелка «не больше» отвечает на вопрос «в какую сторону цель», а
  /// воздержание обещает «ни разу»: у обещания нет стороны
  /// (`computed.abstinence-screen#12`).
  final String? targetIconOverride;

  /// Показывать ли частоту.
  ///
  /// У воздержания частота прибита к суточной ради арифметики деления
  /// пополам и потому есть подробность устройства, а не цель. Форма её тоже
  /// не показывает.
  final bool showsFrequency;
```

и применить их там, где сейчас берутся `state.targetIconGlyph` и строится
пара с частотой: значок — `targetIconOverride ?? state.targetIconGlyph`,
пара с частотой — за `if (showsFrequency)`.

В `show_habit_screen.dart`, в ветви `ShowHabitCard.subtitle`, рядом с уже
существующим `targetOverride: _sleepTargetText(context)`:

```dart
          targetOverride: _abstinenceGoalText(context) ?? _sleepTargetText(context),
          targetIconOverride:
              _abstinenceDefinition == null ? null : banGlyph,
          showsFrequency: _abstinenceDefinition == null,
```

и приватный метод рядом с `_sleepTargetText`:

```dart
  /// Обещание воздержания словами.
  ///
  /// При ненулевом допуске — дословно та фраза, какой у человека спрашивают
  /// величину: одна формулировка, один смысл.
  String? _abstinenceGoalText(BuildContext context) {
    final core.HabitDefinition? definition = _abstinenceDefinition;
    if (definition == null) return null;
    final L10n l10n = L10n.of(context);
    final double allowance = core.abstinenceAllowanceOf(definition);
    if (allowance <= 0) return l10n.abstinenceGoalNever;
    return l10n.abstinenceAllowancePrompt(
      allowance.toStringAsFixed(0),
      core.abstinenceUnitOf(definition),
    );
  }
```

Имя `abstinenceAllowancePrompt` — то, каким уже названа строка вопроса о
величине; взять его из `app_en.arb`, а не отсюда. Значок `banGlyph` —
перечёркнутый круг из того же набора FontAwesome, которым подпись рисует
остальные значки; код глифа взять из `FontAssets` и глазами убедиться, что он
рисуется, а не даёт пустой квадрат.

- [ ] **Шаг 5: прогнать и увидеть зелёное**

Run: `cd uhabits-flutter/app && flutter test test/ui/habits/show/`

- [ ] **Шаг 6: доказать, что сон не сдвинулся**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/ test/ui/habits/show/`
Expected: PASS. У сна подмена текста прежняя, а `targetIconOverride` и
`showsFrequency` приходят пустыми — обе новые ветви для него недостижимы.

- [ ] **Шаг 7: правило и коммит**

```markdown
12. `computed.abstinence-screen#12` Цель воздержания читается обещанием: «Ни разу» при нулевом допуске и той же фразой, какой спрашивают величину, при ненулевом. Значок — знак запрета, частота не показывается.
```

```bash
git commit -m "Write the goal as a promise, not as an arrow and a zero"
```

---

### Task 14: Яркость календаря

**Files:**
- Modify: `uhabits-flutter/app/lib/state/show_habit_model.dart`
- Test: `uhabits-flutter/app/test/ui/habits/show/abstinence_calendar_test.dart`

**Interfaces:**
- Consumes: шов `intensityOf` в `HistoryCardPresenter.buildState`.

- [ ] **Шаг 1: написать падающий тест**

```dart
  testWidgets('the grid brightens along the stretch', (tester) async {
    await pumpAbstinenceCalendar(tester,
        committedFrom: today - 60, lapses: <int>[today - 30]);

    final List<double> shades = intensitiesOf(tester);

    expect(shades[0], greaterThan(shades[29]),
        reason: 'computed.abstinence-screen#13 — сегодня ярче, чем день '
            'после срыва: видно, как шёл');
    expect(shades[30], lessThan(shades[29]),
        reason: 'computed.abstinence-screen#13 — в день срыва провал, и он '
            'виден');
  });

  testWidgets('a lapsed day keeps its own square', (tester) async {
    await pumpAbstinenceCalendar(tester,
        committedFrom: today - 60, lapses: <int>[today - 30]);

    expect(squareAt(tester, today - 30), Square.grey,
        reason: 'computed.abstinence-cell#2 — яркость не перекрашивает срыв '
            'в чистый день');
  });
```

- [ ] **Шаг 2: прогнать, увидеть падение, реализовать**

В `show_habit_model.dart`, рядом с `squareOf`:

```dart
      // Яркость дня есть оценка в этот день: кольцо, сетка и уровень — одна
      // кривая, показанная тремя способами (`computed.abstinence-screen#13`).
      intensityOf: _abstinenceDefinition == null
          ? _sleepIntensity
          : (Entry e) => habit.scores[e.date].value,
```

Сверить, как именно сейчас передаётся сонная яркость, и не сломать её ветвь.

- [ ] **Шаг 3: прогнать и убедиться, что сон не сдвинулся**

Run: `cd uhabits-flutter/app && flutter test test/ui/sleep/ test/ui/habits/show/`

- [ ] **Шаг 4: правило, мутация, коммит**

```markdown
13. `computed.abstinence-screen#13` Яркость дня в календаре есть оценка в этот день. Начало тусклое, серия разгорается, день срыва проваливается, самый яркий день — сегодняшний.
```

Мутация: заменить `habit.scores[e.date].value` на `1.0`.
Expected: падает `the grid brightens along the stretch` — все дни одинаковы.

```bash
git commit -m "Let the calendar show the climb, not just the days"
```

---

### Task 15: Две карточки уходят

**Files:**
- Modify: `uhabits-flutter/app/lib/ui/habits/show/show_habit_screen.dart`
- Test: `uhabits-flutter/app/test/ui/habits/show/abstinence_screen_test.dart`
- Modify: `docs/parity/DEVIATIONS.md`

- [ ] **Шаг 1: написать падающий тест**

```dart
  testWidgets('two cards that can say nothing about this kind are gone',
      (tester) async {
    await pumpAbstinenceScreen(tester, committedFrom: today - 40);

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.bar)), findsNothing,
        reason: 'computed.abstinence-screen#14 — столбцы считают сделанное, а '
            'воздержание ничего не делает');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.frequency)),
        findsNothing,
        reason: 'computed.abstinence-screen#14 — частота у привычки с '
            'прибитой частотой не говорит ничего');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.history)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#13 — а календарь остаётся, он '
            'здесь главный');
  });
```

- [ ] **Шаг 2: реализовать**

В `_isVisible`, для воздержания вернуть `false` для `bar` и `frequency`.

- [ ] **Шаг 3: переписать отступление**

Запись в `DEVIATIONS.md`, которая сейчас утверждает, что воздержание эти карточки **не** трогает, стала неверной. Переписать под то, что есть: карточки скрыты, портированный код не тронут, у прочих привычек всё по-прежнему.

- [ ] **Шаг 4: правило, прогон, коммит**

```markdown
14. `computed.abstinence-screen#14` Столбчатый график и «Частота» воздержанию не показываются: обе карточки считают сделанное, а оно ничего не делает. Портированный код не трогается — скрытие живёт в правиле видимости.
```

```bash
git commit -m "Take away two cards that had nothing to say"
```

---

### Task 16: Путь целиком, реестры, полный прогон

**Files:**
- Test: `uhabits-flutter/app/test/state/abstinence_lifecycle_test.dart`
- Modify: `docs/extensions/COMPUTED.md`
- Modify: `uhabits-flutter/CHANGELOG.md`

- [ ] **Шаг 1: дописать сквозной тест**

К существующему сквозному пути добавить проверку, что после срыва и отмены уровень ведёт себя так, как обещано: растёт с нуля, делится пополам, восстанавливается.

```dart
  test('the level is earned, halved and earned again', () async {
    final AppScope scope = await openScope(path);
    final Habit habit = makeAbstinence(scope, committedFrom: today - 30);

    expect(habit.scores[getToday()].value, closeTo(0.5, 0.02),
        reason: 'computed.lapse-score#14 — месяц есть половина');

    setLapseDay(scope, habit: habit, date: getToday(), lapsed: true);

    expect(habit.scores[getToday()].value, closeTo(0.25, 0.02),
        reason: 'computed.lapse-score#1 — срыв делит пополам, а не обнуляет: '
            'иначе месяц воздержания стоил бы столько же, сколько ничего');
  });
```

- [ ] **Шаг 2: взвести разделы реестра**

Перевести `computed.since` в `- [x]` и убедиться, что все новые правила `computed.streak`, `computed.lapse-score`, `computed.schema`, `computed.backup` и `computed.abstinence-screen` процитированы. Для каждого правила назвать тест и сказать, что именно его роняет; правило, которое держится только на тесте, проходящем при удалённом коде, не взводится, а остаётся с прямой пометкой.

- [ ] **Шаг 3: CHANGELOG**

В `uhabits-flutter/CHANGELOG.md`, одной строкой на каждое, что человек
заметит:

```markdown
- Воздержание: уровень растёт с нуля вместо ста процентов, месяц даёт половину.
- Воздержание: счётчик выдержанного времени до минут, схема поднята до 104.
- Воздержание: календарь разгорается вдоль серии и проваливается в день срыва.
- Воздержание: цель написана обещанием, а не стрелкой и нулём.
- Воздержание: столбчатый график и «Частота» больше не показываются.
- Воздержание: карточка серий и счётчик считают одинаково — прошедшими сутками.
```

- [ ] **Шаг 4: полный прогон**

```bash
cd uhabits-flutter/packages/uhabits_core && dart test
cd uhabits-flutter/app && flutter analyze && flutter test
cd uhabits-flutter && dart tool/parity_coverage.dart --verify
git diff <база ветки>..HEAD --stat -- docs/parity/FEATURES.md   # обязан быть пуст
```

Все четыре зелёные, иначе задача сообщает BLOCKED с выводом, а не обходит его.

- [ ] **Шаг 5: коммит**

```bash
git commit -m "Close the abstinence screen's ledgers"
```

---

## Что в план не входит

- **Кнопка в уведомлении воздержания** по-прежнему ничего не пишет: правка портированного слоя уведомлений со своим ревью.
- **Экспорт одной привычки из меню её экрана** не несёт ни срывов, ни ночей сна — беда унаследована от сна.
- **Определение незнакомого вида не переживает восстановление копии.**
- **Кривая для сна** не трогается ни в одной задаче.
