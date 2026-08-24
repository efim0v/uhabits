# Осознанные отклонения от оригинала

Каждая запись — решение отклониться от поведения Kotlin-версии. Формат:

```
## <feature-id> / <rule-id>
**Что в оригинале:** ...
**Что делаем:** ...
**Почему:** ...
**Дата:** YYYY-MM-DD
```

Пусто — значит отклонений пока нет.

## Спек §4 (заготовка под синхронизацию) / `persistence.schema-habits#1`

**Что в спеке:** сразу добавить `uuid`, `updated_at`, `deleted_at` в `Habits` и `Repetitions`
и заменить физическое удаление на tombstone.

**Что делаем:** схема фазы 1 остаётся ровно версии 25 — как в оригинале. Колонки синка и
tombstone-семантика откладываются до фазы 2 (миграция 26).

**Почему:** правило `persistence.schema-habits#1` требует ровно 18 колонок в заданном
физическом порядке, а `persistence.habit-repository#8` требует физического
`DELETE FROM Habits WHERE id = ?`. Добавить колонки и tombstones сейчас — значит завалить
эти правила и ещё около двадцати соседних, то есть потерять паритет ради задела, который
в фазе 1 никем не читается. `uuid` в `Habits` и так есть с миграции 24, а миграция 26
пишется одним файлом тогда, когда синк действительно начнут делать.

**Дата:** 2026-08-23

## `persistence.sqlite-habit-list-mutations#8` — взаимодействие с включёнными внешними ключами

**Что в оригинале:** `SQLiteHabitList.removeAll()` выполняет `delete from habits`, а затем
`delete from repetitions` — то есть удаляет родителей раньше детей, хотя
`Repetitions.habit references habits(id)`.

**Что делаем:** порядок операторов сохранён дословно. Но поскольку порт включает
`pragma foreign_keys=ON` на каждом соединении (см. запись про `persistence.migration-v22#6`),
первый оператор падает с `SqliteException(787)`, если есть хоть одна запись, и обе таблицы
остаются нетронутыми. Тест это фиксирует явно, а затем выключает внешние ключи, чтобы
проверить намеренное поведение очистки.

**Почему это не ломает приложение:** `removeAll()` в Kotlin-коде не вызывается нигде, кроме
тестовых фикстур (`androidTest/HabitFixtures.kt`, `BaseUserInterfaceTest.kt`,
`HabitCardListCacheTest.kt`). В продакшн-пути его нет. Оригинал переживает это только
потому, что Android-соединение обычно открыто без включённых внешних ключей.

**На что обратить внимание позже:** любой будущий путь массового удаления или импорта
с заменой данных должен либо удалять `Repetitions` первыми, либо временно отключать
внешние ключи. Это ловушка, а не мелочь.

**Дата:** 2026-08-23

## `persistence.migration-runner#6`, `persistence.migration-v18#2`, `persistence.migration-v23#3` — кавычки в миграциях

**Что в оригинале:** миграции 18 и 23 пишут пустую строку двойными кавычками:
`alter table Habits add column unit text not null default ""` и
`update Habits set description = ""`.

**Что делаем:** генератор `tool/generate_migrations.dart` переписывает `""` в `''` при
вшивании скриптов в Dart. Замена точная — это одна и та же пустая строка, — и намеренно
узкая: всё, кроме пустого литерала, генератор считает настоящим идентификатором и падает
с ошибкой, а не угадывает.

**Почему:** в SQL токен в двойных кавычках — идентификатор, а не строка. SQLite исторически
принимает `""` как строку («double-quoted string literal misfeature»), но современные сборки
компилируются с `SQLITE_DQS=1`: терпимо в DDL, строго в DML. Системная libsqlite3 на macOS
терпима, поэтому `dart test` никогда не жаловался. Сборка, которую `sqlite3_flutter_libs`
кладёт в приложение, — нет: миграция 23 бросала `SqliteException(1): no such column: ""`
внутри `AppScope.boot()`, то есть до `runApp()`, и приложение показывало пустой белый экран.

**Как это поймано и как не повторится:** дефект нашёлся только при запуске на симуляторе
iPhone — оба тестовых набора при этом были зелёными. Именно поэтому «запуск на платформе»
стоит в цикле отдельным гейтом. Добавлен тест
`test/database/migration_sql_portability_test.dart`, который падает, если в вшитых скриптах
снова появится двойная кавычка.

**Дата:** 2026-08-23

## `settings.reminder-sound-row-hidden#1`, `settings.screen.structure#7` — скрытые строки настроек показаны отключёнными

**Что в оригинале:** `SettingsFragment.onResume` принудительно прячет строку выбора звука
напоминания, хотя она объявлена первой в категории «Напоминания».

**Что делаем:** строка отображается, но отключена, с пояснением. То же сделано с выбором
публичной папки бэкапов и настройкой канала уведомлений.

**Почему:** это осознанный выбор в пользу видимости пробела. Молча выкинутая строка — это
потерянный функционал, о котором никто не вспомнит; отключённая строка видна и в приложении,
и в реестре, и сама напоминает, что за ней стоит нереализованная платформенная интеграция
(выбор рингтона, Storage Access Framework, каналы уведомлений Android).

**Дата:** 2026-08-23

## `settings.theme.toggle-night-mode#5` — переключение темы без перезапуска экрана

**Что в оригинале:** смена темы пересоздаёт `ListHabitsActivity` с анимацией затухания,
потому что тема в Android применяется на уровне активити.

**Что делаем:** дерево виджетов перестраивается на месте, без перезапуска и без затухания.

**Почему:** во Flutter тема — это значение в дереве, а не свойство активити. Перезапуск
экрана ради смены цвета был бы имитацией чужого ограничения. Видимый результат тот же:
приложение мгновенно перекрашивается.

**Дата:** 2026-08-23

## `reminders.snooze-android12-gate#1..#3` — кнопка «Позже» доступна везде

**Что в оригинале:** начиная с Android 12 действие «Позже» в уведомлении скрыто, потому что
broadcast-receiver больше не может запустить активити выбора задержки.

**Что делаем:** кнопка доступна на всех платформах и версиях.

**Почему:** ограничение, которое её прятало, во Flutter не существует — ответ на действие
обрабатывается в Dart, без перехода через активити. Прятать рабочую кнопку ради имитации
чужого ограничения означало бы потерять функцию, а не сохранить паритет. Прежнее поведение
восстанавливается одним параметром `snoozeActionEnabled: false`, и тест проверяет обе ветки.

**Дата:** 2026-08-23

## `reminders.boot-reschedule`, `reminders.on-show-reminder` — частичный порт напоминаний

**Исправлено 2026-08-23 вечером.** Прежняя редакция этой записи утверждала, что уведомления
планируются и переживают перезагрузку. На Android это было **неправдой в обе стороны**:
`flutter_local_notifications` начиная с 16-й версии не объявляет ни одного своего компонента,
а манифест порта объявлял только boot-приёмник. Будильник срабатывал, явный бродкаст к
`ScheduledNotificationReceiver` не находил компонента, и **ни одно напоминание не доставлялось
вообще**; boot-приёмник исправно перевзводил будильники, которые всё равно некому было
доставить. Кнопки «Да» и «Нет» шли через `ActionBroadcastReceiver` и были мертвы даже при
работающем приложении.

**Что в оригинале:** при срабатывании будильника выполняется код, который показывает
уведомление и тут же планирует следующее; после перезагрузки `BOOT_COMPLETED` вызывает
`scheduleAll()`.

**Что сделано:** приложение само объявляет три приёмника плагина —
`ScheduledNotificationReceiver` (доставка в назначенный момент),
`ScheduledNotificationBootReceiver` (перевзвод после перезагрузки и обновления) и
`ActionBroadcastReceiver` (кнопки «Да» и «Нет»). Уведомления планируются заранее с привязкой
к часовому поясу; на iOS запланированные уведомления переживают перезагрузку сами.

**Чего по-прежнему не хватает, честно:** в момент срабатывания не выполняется никакой Dart-код,
поэтому цепочки «показал — перепланировал» нет; будильники держатся тем, что `scheduleAll()`
вызывается при старте приложения и после каждой команды. Отложенное напоминание, срок которого
истёк при выключенном устройстве, отбрасывается только при следующем запуске.

**Урок, который стоит того, чтобы его записать:** этот дефект пережил четыре аудита, потому что
`manifest_components_test.dart` утверждал `hasLength(1)` для обычных приёмников — то есть прямо
требовал, чтобы двух недостающих там не было. Тест охранял баг вместо того, чтобы его ловить,
и реестр был зелёным, пока напоминания не работали совсем.

**Дата:** 2026-08-23

## `widgets.dimensions#4` — размеры виджетов по умолчанию теперь действительно применяются

**Что в оригинале:** `BaseWidget` читает `defaultWidth` и `defaultHeight` в своём init-блоке,
но это абстрактные свойства, которые каждый подкласс инициализирует уже после вызова
конструктора базового класса. Базовый класс всегда получает ноль, поэтому задокументированные
значения (125, 200, 250, 300) **никогда не применялись**.

**Что делаем:** порт вычисляет их лениво, при первом обращении, поэтому значения реальны.

**Почему исправлено, а не воспроизведено:** воспроизвести пришлось бы, сохранив ошибку
порядка инициализации Kotlin, которой в Dart просто нет — ленивое вычисление здесь
естественный способ выразить ту же конструкцию. Итог совпадает с тем, что в оригинале
написано намеренно; расходится он только с тем, что там получилось случайно. Видимое
следствие: виджет, добавленный на домашний экран, получает заявленный размер.

**Дата:** 2026-08-23

## `persistence.migration-runner#5` — ловушка неатомарной миграции (воспроизведена, не исправлена)

**Что в оригинале:** `user_version` пишется после каждой миграции целиком, а операторы внутри
одной миграции выполняются по одному. Прерывание в середине многооператорной миграции
оставляет базу в промежуточном состоянии с прежним номером версии.

**Что делаем:** воспроизводим как есть.

**Почему это важно знать:** мы на это наступили. Падение на двойных кавычках останавливало
миграцию 23 на третьем операторе, когда первый уже добавил колонку `question`. Версия
осталась 22, и каждый следующий запуск падал уже с `duplicate column name: question` — то
есть исходный баг чинился, а база оставалась битой навсегда. Лечится только переустановкой.

**Почему не исправлено:** обернуть каждую миграцию в транзакцию нельзя механически —
миграция 22 открывает собственную транзакцию, а вложенные SQLite не поддерживает. Правило
`persistence.migration-runner#5` описывает возобновление с первой неприменённой версии
как намеренное поведение. Исправление — это отдельное продуктовое решение, а не деталь порта.

**Дата:** 2026-08-23

## Что теряет пользователь на фичах со статусом superseded

Статус `- [~]` означает «порт делает это иначе». Иначе — не всегда бесследно.Ниже перечислено всё, что при этом реально меняется для пользователя; фичи, где потерьнет, в список не попали.

### `charts-canvas-theming.dataview-scrolling`

**Чем заменено:** AndroidDataView is replaced by app/lib/ui/common/scrollable_chart.dart, a single widget covering both Android scrollers; the rules describe android.widget.Scroller, GestureDetector and ValueAnimator internals, and the file documents each substitution.

**Что меняется для пользователя:** the fling coasts on Flutter's FrictionSimulation rather than Scroller's curve, so a fling travels a slightly different distance (velocity halving, direction, whole-column snapping and the no-scrolling-into-the-future clamp are all kept); and the offset is capped at the legacy ScrollableChart default of 12*200 columns instead of #9's unbounded scroll into empty history.

### `dialogs.single-current-dialog`

**Чем заменено:** Every picker in the port is an awaited modal route on the Navigator (showColorPickerDialog, showFrequencyPickerDialog, showWeekdayPickerDialog, showTimePicker, showConfirmDeleteDialog, showCheckmarkDialog, showNumberDialog), so 'one at a time', 'the history editor stays under the entry popups' (#5) and 'leaving the screen closes the popup' (#6) fall out of route stacking; there is no process-wide WeakReference registry to reproduce.

**Что меняется для пользователя:** None in any flow the app has today, because each call site awaits its dialog. Nothing enforces the rule globally: if two dialogs were ever requested concurrently they would stack rather than the first being dismissed, whereas Android would have closed the first.

### `edit-habit.instance-state`

**Чем заменено:** The editor's form lives in ordinary Flutter State (EditHabitModel + TextEditingControllers), which survives rotation without an onSaveInstanceState Bundle; there is no Bundle round trip to port, and the ledger's own Notes direct exactly this.

**Что меняется для пользователя:** Form values are lost if Android kills the process while the editor is open — the Android Bundle restored habitId/type/colour/frequency/reminder, and no RestorationMixin or restorationScopeId is wired in the port. Rotation itself loses nothing, and the #3 bug (Target Type silently resetting to At least on rotation) is not reproduced, so Target Type now survives.

### `intents.pending-intent-request-codes`

**Чем заменено:** The port authors no PendingIntents in app code: widget taps are URI-keyed launch intents built by app/android/app/src/main/kotlin/org/isoron/uhabits/widgets/WidgetIntents.kt via HomeWidgetLaunchIntent.getActivity, and notification-button intents are owned by flutter_local_notifications, so request codes and FLAG_MUTABLE templates have nothing left to key.

**Что меняется для пользователя:** Two real ones. (a) Upstream showHabit used TaskStackBuilder, so Back from a widget-opened detail screen landed on the habit list; the port relies on pushing the detail route onto the app's own stack, which only behaves the same once that routing exists. (b) Rules #10/#16/#17 (RemoteViews template + fill-in intents) have no target at all because stack widgets were already removed upstream — noted in the port's AndroidManifest.xml. Otherwise no loss: every destination stays distinct because each uhabits://widget/... URI is distinct per habit, widget and action, which is what request codes bought. Note the Dart consumer of those URIs is still missing — that gap is real work, tracked under intents.widget-receiver-dispatch and platform-glue.deep-link-edit-entry, not here.

### `io.logging`

**Чем заменено:** AppScope wires StandardLogging over Dart stdout/stderr (app/lib/state/app_scope.dart); Dart output already reaches logcat on Android and os_log on iOS, so the android.util.Log adapter (#3, #6, #7) and its Dagger @AppScope binding (#8) have nothing to map onto.

**Что меняется для пользователя:** none for a user; log lines lose the per-logger logcat tag, so a developer filtering logcat by tag must filter by message text instead.

### `io.printf-format`

**Чем заменено:** Dart has no printf, so the port ships its own formatter in packages/uhabits_core/lib/src/io/printf.dart instead of delegating to java.lang.String.format or the npm sprintf-js package that the one remaining rule (#4) describes; there is no Kotlin/JS target to port.

**Что меняется для пользователя:** the pattern behaviours (#1, #2, #5) are ported and cited, and the port is deliberately locale-independent where the JVM actual was not — which is a real, visible difference and not "none", as this entry used to claim.

Kotlin renders a habit's numeric label through `String.format(Locale.getDefault(), …)` and `DecimalFormat`, so on a German or French device the habit-list cell, the Show-habit subtitle, the target card and the Checkmark widget all read "2,5". The port's Dart hosts read "2.5" everywhere, by this decision. Its two *native* widget hosts do not follow the decision: `NumberFormat.kt` on Android is locale-aware, and `CheckmarkWidget.swift` on iOS is split down the middle — `String(format:)` with a nil locale prints "1.5k" while a default `NumberFormatter` prints "2,5" in the same view. So on a comma device the same value can read "2.5" in the app and "2,5" on the home screen beside it.

Entering and saving are unaffected: `audit9.number-popup-follows-the-device-locale#1` put the entry popup's formatting, its keypad and its parser on the device locale, so a comma typed on a comma device is read correctly. What differs is the label only. Recorded here rather than fixed because choosing a side would either reverse this deviation or push two faithfully-ported native hosts away from Kotlin; found by the twenty-fifth audit pass, whose skeptic refuted the finding on the merits and named this inaccuracy instead.

### `notifications.actions`

**Чем заменено:** The action buttons are built through flutter_local_notifications' own action API (app/lib/platform/flutter_notification_tray.dart), which exposes no NotificationCompat.WearableExtender; #4's duplicated extender action list and its stripe bitmap have no equivalent, and modern Wear OS bridges the phone's actions itself.

**Что меняется для пользователя:** a paired Pebble — the device the upstream code comment names as the reason for the extender — no longer shows the Yes/No/Enter/Later buttons on the watch.

### `notifications.sound`

**Чем заменено:** The ledger's own gap-found entry settings.reminder-sound-row-hidden records that the picker row is force-hidden upstream and says a Flutter port should ship no sound-picker row and use the platform default; #1-#6 are the RingtoneManager plumbing behind that dead row, while #7 and #8 (including the retry-without-sound path for Xiaomi) are ported and cited.

**Что меняется для пользователя:** none — the picker is unreachable in the Kotlin build too, so reminders play the system default notification sound in both builds.

### `platform-glue.attribute-set-utils`

**Чем заменено:** These rules parse custom XML attributes off an AttributeSet during Android view inflation; the port has no XML layouts and no inflated custom views — Flutter widgets take constructor arguments — so ISORON_NAMESPACE has nothing to read. The ledger's own Notes say a pure Flutter port drops this entirely.

**Что меняется для пользователя:** None. The quirks these rules pin (Boolean.parseBoolean leniency, getFloatAttribute swallowing NumberFormatException while getIntAttribute throws) are artefacts of parsing strings out of XML; a Dart constructor argument is already typed.

### `platform-glue.di-activity-component`

**Чем заменено:** The @ActivityScope graph is replaced by per-route state objects and providers; the port has one activity, and its screens (habit_list_screen, show_habit_screen, edit_habit_screen) build their own models rather than resolving an activity-scoped component.

**Что меняется для пользователя:** None. Rule #5's ordering constraint (themeSwitcher.apply() before reading views) is moot because the theme is a value in the widget tree — recorded in DEVIATIONS.md for settings.theme.toggle-night-mode#5. Rule #6 (nothing survives a configuration change) is if anything reversed: Flutter state survives rotation, which a user experiences as the list not resetting.

### `platform-glue.di-app-component`

**Чем заменено:** The kotlin-inject @Component/@AppScope graph is replaced by the hand-wired container in app/lib/state/app_scope.dart plus package:provider; AppScope.open takes the Database, PreferencesStorage and both dispatchers as arguments, which is what rule #9's `open @Provides` override hook existed for.

**Что меняется для пользователя:** None from the DI substitution itself — wiring is not observable. But be clear about what this label does NOT cover: several singletons rule #2 enumerates (notificationTray, reminderScheduler, widgetUpdater, pendingIntentFactory, genericImporter) exist in the port yet are never constructed at startup, so at runtime the app schedules no reminders and publishes no widget data. That is real work and is tracked under platform-glue.app-startup-order.

### `platform-glue.di-receiver-components`

**Чем заменено:** There are no BroadcastReceivers in the port that resolve a DI graph: WidgetBehavior is a plain Dart class constructed in app/lib/state/widget_sync.dart, and FireSettingReceiver belongs to the Tasker integration the project already dropped (see the four platform-glue.tasker-* dispositions).

**Что меняется для пользователя:** None. Rules #1-#3 describe per-broadcast component creation, #4 describes a crash when the static component is uninitialised, and #5 observes WidgetBehavior is stateless — none is reachable by a user.

### `platform-glue.dimension-utils`

**Чем заменено:** dp-to-pixel conversion is replaced by Flutter logical pixels (a logical pixel is Android's dp); the FontAwesome typeface of rule #4 is declared in app/pubspec.yaml instead of being lazily built from an asset; rule #5's depth-first view-tree walk and rule #6's ViewCompat layout-direction probe have no widget-tree analogue.

**Что меняется для пользователя:** One real one, small and specific: rule #2's sp-vs-dp distinction. Upstream calls spToPixels in three places, not one: RingView's percentage text (uhabits-android/.../common/views/RingView.kt:87), the check-mark cell glyphs (.../habits/list/views/CheckmarkButtonView.kt:170-174, `sp(12f)` / `sp(13f)` / `sp(14f)`) and the empty-list icon (.../habits/list/views/EmptyListView.kt:48, `sp(40f)`). Each of the three grows and shrinks with the OS font-size / accessibility text-scale setting. Two of them are reproduced: EmptyListView is a Flutter `Text`, which applies the ambient `textScaler` by itself, and `CheckmarkButtonView` (app/lib/ui/habits/list/entry_button_views.dart) takes a `TextScaler` that `EntryPanel` fills from `MediaQuery.textScalerOf(context)` (`audit4.check-mark-cell-glyphs-no-longer#1`). What is still deviating is RingView alone: the port paints its percentage text on a canvas at a fixed logical size, so it does not scale. Every other upstream measurement was dp, which Flutter reproduces exactly.

Corrected after the fourth audit pass. This paragraph used to read "Upstream's only spToPixels call is RingView's percentage text … and `textScaler` appears nowhere in app/lib or packages/uhabits_core/lib", which was wrong on both counts and hid a real defect behind an accepted deviation: the habit-row glyphs had stopped following the text-scale setting, and the record said no such call site existed.

### `platform-glue.styled-resources`

**Чем заменено:** Android theme-attribute resolution (obtainStyledAttributes / R.attr) is replaced by the ported Theme value object in packages/uhabits_core/lib/src/gui/theme.dart and app/lib/ui/theme/app_theme.dart; the palette rule #3 fetches from R.attr.palette is a plain list already pinned by the checked charts-canvas-theming.* features.

**Что меняется для пользователя:** None — every colour, dimension, boolean and float these five rules fetch is fetched from the Theme object instead, and the values themselves are asserted by the theming features. Rule #4's fixedTheme test hook is unnecessary because a Dart test passes a Theme directly.

### `platform-glue.tasker-parse-intent`

**Чем заменено:** This is the parsing half of the Tasker/Locale plugin, whose four sibling features (tasker-action-constants, tasker-edit-setting-screen, tasker-edit-setting-result, tasker-fire-setting) are already dispositioned as dropped by owner decision; with the edit screen and the fire receiver gone, nothing produces a setting bundle for SettingUtils.parseIntent to read.

**Что меняется для пользователя:** Nothing beyond the already-accepted loss of the Tasker plugin itself. Keeping this one rule set outstanding would imply a parser could be shipped on its own, which it cannot — it has no caller.

### `platform-glue.test-mode-and-fixtures`

**Чем заменено:** This is the Kotlin instrumentation harness contract — the Class.forName probe, test.db, HabitsApplicationTestComponent, UiDevice clock shell commands and the lastReceivedIntent statics. The port's tests inject a Database, a PreferencesStorage and both dispatchers straight into AppScope.open (app/lib/state/app_scope.dart) and drive time with setToday, so there is no test-mode branch in production code to detect.

**Что меняется для пользователя:** None — no rule here is reachable by a user. Rule #2's test.db filename and the startup delete exist only to serve the Class.forName probe, and rule #7's static lastReceivedIntent fields exist only so instrumentation can assert an alarm fired.

### `platform-glue.transient-ui-helpers`

**Чем заменено:** Snackbars go through ScaffoldMessenger (app/lib/ui/settings/data_actions.dart, about_screen.dart); the WeakReference dialog bookkeeping of rules #3-#5 is replaced by showDialog + Navigator, which already shows one route at a time and disposes it on pop; and rules #6-#7's restartWithFade is replaced by the in-place theme rebuild recorded in DEVIATIONS.md for settings.theme.toggle-night-mode#5.

**Что меняется для пользователя:** Two cosmetic ones. (a) Toggling pure-black dark mode no longer fades out and back over 500 ms — the tree repaints instantly; same end state, recorded deviation. (b) Rule #1 force-sets snackbar text to white regardless of theme; the port lets it follow the Material theme, so the colour can differ from upstream in a dark theme. Rule #9's 250 ms synthetic-MotionEvent keyboard hack is replaced by autofocus, which the ledger's Notes explicitly ask for.

### `platform-glue.translators-credits-generation`

**Чем заменено:** The Gradle updateTranslators task regenerated about_translators.xml from two CSVs at build time; the port carries the generated result as data instead — AboutScreen.translators in app/lib/ui/about/about_screen.dart is the same grouped list, and the card a user sees is already covered by the checked settings.about.screen#8.

**Что меняется для пользователя:** None today: the same names appear under the same language headings. The cost is a maintenance regression, not a user-facing one — the list no longer regenerates from translators-classic.csv / translators-crowdin.csv, so the endonym table, the Winning>=10 / Translated>=100 / Approved>0 threshold and the REMOVED-name filter are frozen into the data, and a new translator's name has to be added by hand or the credits go stale.

### `reminders.dependency-wiring`

**Чем заменено:** Dagger is replaced by AppScope's plain constructor wiring, and the Android widget bridge is file-based (home_widget) rather than a per-receiver DI component, so #6's @ReceiverScope annotation and the per-onReceive WidgetComponent have no counterpart; #1-#5 and #7 are ported and cited.

**Что меняется для пользователя:** none from this feature — but note the reminder subsystem is still never instantiated at app startup; that gap is tracked as real work under reminders.reschedule-on-command and reminders.app-start-and-permission, not hidden here.

### `reminders.snooze-android12-gate`

**Чем заменено:** DEVIATIONS.md records dropping the gate: the 'Later' action is offered on every platform and version because the notification-trampoline restriction that hid it does not apply when the response is handled in Dart, and the old behaviour is restorable with snoozeActionEnabled: false (both branches tested). #2 is the receiver-side half of the same gate.

**Что меняется для пользователя:** none — the port offers a snooze action where upstream hides it on Android 12+; nothing is taken away.

### `settings.intro.slides`

**Чем заменено:** The intro is a Flutter route (app/lib/ui/intro/intro_screen.dart), not an Activity, so #7's manifest declaration (empty label, Theme.AppCompat.Light.NoActionBar) has no counterpart; the three slides, their copy, images and background colours are ported and cited.

**Что меняется для пользователя:** none — the intro is still full-screen with no title bar.

### `settings.reminder-sound-row-hidden`

**Чем заменено:** The port ships no ringtone picker and uses the platform default notification sound, which is what this feature's own note says a port should do; DEVIATIONS.md records rendering the 'Reminder sound' row disabled with an explanation instead of hiding it, which is why #4's exactly-two-rows count no longer holds.

**Что меняется для пользователя:** none behaviourally — the port shows a greyed-out 'Reminder sound' row where upstream hides it; the sound is the system default in both.

### `settings.screen.structure`

**Чем заменено:** The only uncited rule (#8) is Android BackupManager.dataChanged — whose backup agent is already dispositioned superseded as persistence.android-backup-agent — plus the PreferenceFragment idiom of re-running updateWeekdayPreference on every change, which the Flutter settings screen gets by rebuilding. Rules #1-#7 are ported and cited.

**Что меняется для пользователя:** none beyond the already-recorded loss of Android cloud backup of preferences and the database.

### `settings.theme.theme-modes`

**Чем заменено:** app/lib/state/theme_model.dart reads MediaQuery.platformBrightness and the theme is a value in the widget tree, so the @ActivityScope switcher (#11), applyDialog styles (#10), the Activity cast (#12), the per-call View.currentTheme() helper (#13) and the SDK<29 branch (#5) have no counterpart; the eight behavioural rules are ported and cited.

**Что меняется для пользователя:** on Android 9 and older upstream forces the light theme even when the user picked 'automatic', while the port follows the system setting there — a behaviour difference in the user's favour, nothing removed.

### `settings.theme.toggle-night-mode`

**Чем заменено:** DEVIATIONS.md records that a theme change rebuilds the widget tree in place instead of recreating the activity; #7 (finish + fade + 500 ms postDelayed) and #9 (restart on resume when pure black changed) describe exactly that restart mechanism.

**Что меняется для пользователя:** the cross-fade and the half-second delay when switching themes; the app recolours instantly instead.

### `time-picker.accessibility-announcements`

**Чем заменено:** Flutter's showTimePicker ships its own semantics: the header is labelled with the formatted time, the hour and minute selectors expose Semantics(value: '<mode announcement> <value>') with increase/decrease actions, and the AM/PM control is button: true — so the two vendored Accessible* View subclasses and Utils.tryAccessibilityAnnounce have nothing to port.

**Что меняется для пользователя:** Screen-reader wording is Material's, not the AOSP strings, and there is no explicit spoken announcement for each digit typed in keyboard-entry mode (Flutter conveys it through changed semantics values instead). Roles and the selected hour/minute are still announced.

### `time-picker.clock-face-rendering`

**Чем заменено:** The dial is drawn by Flutter's showTimePicker, so CircleView / AmPmCirclesView / RadialTextsView / RadialSelectorView and the pickers.xml multipliers have nothing to port — these rules are the AOSP fork's pixel geometry, not behaviour the port chooses.

**Что меняется для пользователя:** The clock face looks like Material's, not the fork's: AM/PM is a segmented two-button toggle instead of two circles on the dial, 24-hour mode uses Material's ring layout rather than the fork's outer/inner rings, and the disappear/reappear and label-pulse animations differ. Function is unchanged — every hour and every minute is still selectable by tap or drag.

### `time-picker.haptic-feedback`

**Чем заменено:** Flutter's showTimePicker carries its own _vibrate() (HapticFeedback.vibrate, throttled by _kVibrateCommitDelay) fired on hour, minute and mode changes, so the vendored HapticFeedbackController and its Settings.System ContentObserver have nothing to port.

**Что меняется для пользователя:** No haptic ticks at all on iOS — Flutter's picker skips vibration on iOS/macOS by design. On Android the tick fires on committed value changes rather than on every 125 ms of dial movement, and the system-haptics gate is applied by the platform channel instead of being re-read through a ContentObserver, so toggling the system setting mid-dialog is not observed.

### `time-picker.radial-dialog`

**Чем заменено:** app/lib/ui/habits/edit/edit_habit_screen.dart already calls Flutter's Material showTimePicker for the reminder, and the vendored dialog's Clear button is reproduced as the separate editHabit.reminderClear control on the reminder row; the AOSP fork is not shipped.

**Что меняется для пользователя:** Clear is a button on the reminder row instead of a button inside the dialog. The dialog is Material's — Cancel/OK plus a keyboard-entry toggle rather than the fork's Clear/Done — and it is not tinted with the habit colour, so the accent that edit-habit.color-control#5 describes is gone (that rule stays outstanding under color-control). A radial hour/minute dial, 12/24-hour mode, per-minute granularity and keyboard entry are all still there.

**Дата:** 2026-08-23

## Ошибки самого реестра

Реестр снят с кода автоматически и в отдельных местах разошёлся с источником. Там, где
правило противоречит Kotlin-коду, порт следует **коду**, а правило помечается здесь.

### `show-habit.target-card#19`

**Что утверждает правило:** график цели имеет высоту 300dp, а `baseSize = height / rowCount`.

**Что в коде:** `TargetChart.onMeasure` читает высоту из спецификации только когда
`layoutParams.height` равен `MATCH_PARENT`, а `show_habit_target.xml` задаёт фиксированные
300dp. Реальная измеренная высота — `labels.size * 20dp`, и ровно это утверждает соседнее
правило `charts-canvas-theming.target-chart#3`.

**Решение:** порт воспроизводит поведение кода. Правило #19 оставлено непроцитированным, а не
«выполнено» ценой утверждения, противоположного источнику. Два агента независимо пришли к
одному выводу.

**Дата:** 2026-08-23

## `list-habits.screen-layout` — убрана плавающая кнопка, которой в оригинале нет

**Что в оригинале:** добавление привычки — пункт тулбара `actionCreateHabit` с
`showAsAction="always"` в `res/menu/list_habits.xml`. Плавающей кнопки в приложении нет
вообще.

**Что было в порте:** ранняя волна добавила `FloatingActionButton`, потому что на тот момент
тулбарного меню ещё не существовало и добавить привычку было нечем. Когда меню приземлилось,
кнопок стало две, а в pure black теме плавающая ещё и сливалась с фоном.

**Что делаем:** плавающая кнопка удалена, добавление идёт через тулбар, как в оригинале.

**Почему это важно как урок:** заглушка, поставленная «пока нет настоящего», переживает
появление настоящего, если её не убрать явно. Нашлось только запуском на устройстве — в
тестах обе кнопки мирно сосуществовали.

**Дата:** 2026-08-23

## `verify.sticky-dismiss-unrouted` — смахивание уведомления замечается с задержкой

**Что в оригинале:** у уведомления есть delete-intent, поэтому смахивание мгновенно доходит
до `ReminderController.onDismiss`, и «липкое» напоминание тут же возвращается на экран.

**Что делаем:** `flutter_local_notifications` 18.0.1 не даёт ни delete-intent, ни колбэка на
смахивание (проверено по исходникам плагина). Порт поэтому *обнаруживает* смахивание: при
возврате приложения на передний план он сверяет собственный реестр уведомлений с
`getActiveNotifications()` и отдаёт исчезнувшие в `onDismiss`.

**Что это меняет:** оба следствия правила восстановлены — липкие напоминания возвращаются, а
реестр перестаёт считать активным то, чего уже нет. Но возврат происходит не в момент
смахивания, а при следующем открытии приложения.

**Дата:** 2026-08-23

## Ответ на уведомление при мёртвом процессе (Android)

**Что в оригинале:** кнопки «Да» и «Нет» обрабатывает broadcast-receiver, которому не нужен
живой процесс приложения.

**Что делаем:** зарегистрирован фоновый обработчик `reminderBackgroundResponse`, но он лишь
пересылает ответ работающему приложению через `IsolateNameServer` и больше ничего не делает.

**Почему:** обработать нажатие прямо в фоновом изоляте означало бы открыть второе соединение
к той же базе за спиной у живого приложения. Цена честная и названа: «Да», нажатое при
полностью выгруженном процессе, теряется. Отдельной фичи в реестре под этот пробел нет, и
агент её не выдумал — что правильно.

**Дата:** 2026-08-23

## Счётчик активных задач при упавшей задаче

**Что в оригинале:** `CoroutineTaskRunner.execute` увеличивает `activeCount`, запускает
`doInBackground`, и только потом уменьшает счётчик. Если задача бросает исключение,
уменьшения не происходит — счётчик остаётся завышенным навсегда.

**Что делаем:** счётчик освобождается на любом пути, включая исключение; само исключение
по-прежнему не перехватывается и уходит наружу. `onPostExecute` остаётся эпилогом успеха и
для упавшей задачи не вызывается.

**Почему:** в Kotlin утечку никто не наблюдает — исключение из корутины уходит в
uncaught-обработчик Android и убивает процесс. В Dart то же исключение становится
необработанной асинхронной ошибкой: приложение продолжает работать, а
`ListHabitsRootView.TaskProgressBar`, видимый ровно пока `activeTaskCount != 0`
(`charts-canvas-theming.task-progress-bar#4`), остаётся на экране до конца сессии. Дословный
перенос здесь даёт пользователю худшее поведение, чем оригинал, — именно эту полосу загрузки
и увидел пользователь на симуляторе. Правило:
`feedback.the-task-progress-bar-never-hides-again#1`.

**Дата:** 2026-08-24

## Атомарность миграций базы

**Что в оригинале:** `Database.migrateTo` в uhabits-core штампует `user_version` после каждой
отдельной миграции и никакой транзакции не открывает. Но вызывается он не напрямую:
`HabitsDatabaseOpener` наследует `SQLiteOpenHelper`, а `getDatabaseLocked` оборачивает весь
апгрейд в одну транзакцию.

**Что делаем:** `migrateTo` в порте открывает транзакцию сам. Вложенные маркеры
`begin transaction` / `commit` внутри миграции 22 транслируются в `SAVEPOINT` / `RELEASE`
(sqlite отвергает вложенный `BEGIN`, а Android так же превращает такой оператор в
савпойнт средствами `SQLiteSession`). Операторы `pragma` дополнительно повторяются после
коммита: внутри транзакции они не действуют.

**Почему:** дословный перенос одного лишь `migrateTo` даёт не паритет, а прямо противоположное
поведение — упавшая на середине миграция оставляет применённый префикс в файле, а
`user_version` — на старой версии. Следующий запуск повторяет ту же миграцию с первого
оператора и падает на уже применённом DDL (`duplicate column name: question`) — навсегда.
Этот сценарий в проекте уже случался. На Android то же исключение — разовый безобидный сбой.
Правило: `feedback.migrations-are-not-atomic#1`; следствие правила
`persistence.migration-runner#5` («прерванный апгрейд продолжается с первой непримененной
версии») в Android-приложении не наблюдаемо и помечено в реестре как неприменимое.

**Дата:** 2026-08-24

## Ссылка «Оценить приложение» вне Android

**Что в оригинале:** `@string/playStoreURL` = `market://details?id=org.isoron.uhabits`, один
литерал для всех сборок — потому что сборка одна, Android.

**Что делаем:** на Android литерал сохранён дословно. На iOS и macOS используется та же
страница листинга по https (`https://play.google.com/store/apps/details?id=...`).

**Почему:** схему `market:` вне Android не регистрирует ни одно приложение, поэтому строка
«Оценить приложение» в настройках и в «О программе» там не просто иногда не срабатывает — она
мертва всегда и показывает «Не найдено приложение для этого действия». Своего листинга в App
Store у порта нет, поэтому честная замена — та же страница, открываемая браузером. Правило:
`feedback.rate-app-row-is-dead-outside-android#1`.

**Дата:** 2026-08-24

## Восстановление после непригодной версии базы

**Что в оригинале:** HabitsApplication.onCreate's `catch (e: UnsupportedDatabaseVersionException)` at HabitsApplication.kt:54-60 is unreachable: DatabaseUtils.initializeDatabase (DatabaseUtils.kt:52-58) only constructs HabitsDatabaseOpener, and an SQLiteOpenHelper opens nothing until getWritableDatabase(). The file is first opened lazily through HabitsApplicationComponent.providedDb (:89) when `val habitList = component.habitList` runs at HabitsApplication.kt:73 — thirteen lines past the catch — so the throw from HabitsDatabaseOpener.onUpgrade:54 / onDowngrade:70 escapes Application.onCreate with no BaseExceptionHandler installed yet. The Android app crashes on every launch and the rename inside the catch never runs, leaving databases/uhabits.db exactly where it was.

**Что делаем:** AppScope._initializeDatabase catches UnsupportedDatabaseVersionException, renames the file to `<path>.invalid`, opens a fresh database and boots onto an empty habit list, logging the quarantine through BugReportLogging.

**Почему:** A crash loop leaves the user with an app that cannot be opened at all and no way to act from inside it; the port already awaits boot() before runApp, so the same throw would be a blank window rather than even a crash dialog. The recovery already existed in the port and is kept — what changes is that the ledger and the tests stop calling it parity.

**Дата:** 2026-08-24


## Повреждённая база отставляется в сторону, а не удаляется

**Что в оригинале:** HabitsDatabaseOpener passes a null errorHandler to SQLiteOpenHelper (HabitsDatabaseOpener.kt:35), so AOSP's DefaultDatabaseErrorHandler is installed; SQLiteDatabase.open() catches the SQLiteDatabaseCorruptException the framework raises for SQLITE_CORRUPT and SQLITE_NOTADB and calls onCorruption(), which DELETES the file, then reopens with CREATE_IF_NECESSARY. The user's bytes are gone.

**Что делаем:** AppScope._quarantine renames the unreadable file to `<path>.invalid` and opens a fresh database in its place. The outcome the user sees — an app that opens, empty — is identical; the damaged file survives on disk.

**Почему:** That file is the only copy of the user's history, and much real corruption is partial and recoverable with external tools. Deleting it makes the loss permanent for no behavioural gain, and it is consistent with the branch the port already had for the unsupported-version case.

**Дата:** 2026-08-24


## Ненастроенный виджет на iOS

**Что в оригинале:** There is no such thing as an unconfigured widget. HabitPickerDialog leaves RESULT_CANCELED unless the user picks a habit (`widgets.config-picker#11`), so the launcher drops the placement and no widget ever exists without a binding. HabitPickerDialog.kt:68-74 also refuses to offer an archived habit, so no binding to one can be created.

**Что делаем:** WidgetKit places a widget before the user configures it and has no RESULT_CANCELED to return, so `WidgetStore.resolve` (app/ios/HabitsWidget/HabitSelection.swift) falls back, at render time and persisting nothing, to `allHabits().first { !$0.isArchived && eligible($0) }`. This fix narrows that pre-existing fallback so it refuses exactly the habits the picker refuses — archived always, plus the widget's type filter — rather than removing it.

**Почему:** Removing the fallback would leave every freshly dropped iOS widget on the 'open Loop Habit Tracker to set up this widget' card with no way to reproduce Android's 'the placement never happens'. Leaving it unfiltered was the defect: a user whose oldest habits are archived got a live Checkmark toggle button bound to a habit they had retired. Filtering it is the closest available reading of `widgets.config-picker#3`.

**Дата:** 2026-08-24


## Ограничение публикуемой истории 750 днями

**Что в оригинале:** `HistoryWidget.refreshData` assigns `HistoryCardPresenter.buildState(...).series` straight onto the chart in-process. The series is unbounded — it runs from the habit's oldest known entry to today, so a ten-year-old habit hands the chart 3,650 squares for the cost of an array reference.

**Что делаем:** Publishes the same presenter's series, from the oldest known entry to today, truncated at 750 days.

**Почему:** The port serialises the series into shared storage on every publish, for every habit in the catalogue, where Kotlin passes a reference inside one process. 750 is set above the widest grid any launcher can produce: `squareSize = round((height - 2*padding) / 8)` is at least 12dp at the provider's declared `minHeight` of 100dp, so a full-width ~1280dp landscape strip — the (maxWidth x minHeight) pair `BaseWidgetProvider` hands `landscapeRemoteViews` — is 105 columns, i.e. 735 days. No reachable geometry draws past the cap, so the rendered grid is identical to Kotlin's; only the wire contract is bounded.

**Дата:** 2026-08-24


## Строка привычки достижима с клавиатуры

**Что в оригинале:** HabitCardListView.bindCardView attaches only `cardView.setOnTouchListener { _, ev -> detector.onTouchEvent(ev); true }` and never setOnClickListener, so HabitCardView's FOCUSABLE_AUTO resolves to NOT_FOCUSABLE. Keyboard focus lands only on grid cells, and there is no keyboard path to the habit detail screen.

**Что делаем:** After this fix both the row's InkWell and every grid cell are focusable: Tab reaches the row (Enter opens the detail screen) and then each cell (Enter/Space toggles or edits).

**Почему:** The defect was that the primary action had no keyboard path. Restoring the cells restores it; deleting the row's focus node would remove a working access path rather than add one, and would make the app less operable than either side.

**Дата:** 2026-08-24


## Удержание клавиши подтверждения не даёт долгого нажатия

**Что в оригинале:** View.onKeyDown arms checkForLongClick for confirm keys, so holding ENTER/SPACE/DPAD_CENTER on a cell reaches onLongClick — the notes/number popup when isShortToggleEnabled, the toggle otherwise.

**Что делаем:** ActivateIntent/ButtonActivateIntent map to the click branch only; there is no key-hold path to onLongPress.

**Почему:** Both branches are still reachable from the keyboard for numerical cells (onClick and onLongClick are the same `edit`), and for boolean cells the branch the preference puts on the tap is the one the report named as lost. Reproducing Android's key-hold timer inside a Flutter Action has no idiomatic counterpart and was not worth inventing for this fix.

**Дата:** 2026-08-24


## Формулировки подсказок берутся из MaterialLocalizations

**Что в оригинале:** AppCompat names the two overflow buttons "More options" (abc_action_menu_overflow_description), the action-mode close control "Done" (abc_action_mode_done, via ?attr/actionModeCloseContentDescription) and the SearchView X "Clear query" (abc_searchview_description_clear).

**Что делаем:** Uses MaterialLocalizations.showMenuTooltip ("Show menu"), closeButtonTooltip ("Close") and clearButtonTooltip ("Clear text").

**Почему:** flutter_localizations ships these translated in every locale the app supports, whereas a new ARB key would land untranslated in the other 47 locales — a worse accessibility outcome than a one-word wording difference. "Show menu" is also what the port's show-habit PopupMenuButton already announces, so the two overflow buttons in the app now agree instead of differing.

**Дата:** 2026-08-24


## Освобождение счётчика задач на пути ошибки

**Что в оригинале:** An exception out of `withContext(ioDispatcher) { doInBackground() }` resumes the launch body on the main dispatcher and terminates it there; `activeCount--` and `onTaskFinished` are never reached, and on Android the uncaught exception ends the process so nothing observes the leak.

**Что делаем:** The failure half of the epilogue (`_release`: `_activeCount--` plus `onTaskFinished`) is still run on every path, but it is now handed to `_mainDispatcher.dispatch(...)` instead of running in the `.then` microtask, and the original error is re-thrown only after that dispatch has run. So the counter release and the listener notification now land after any progress callbacks `doInBackground` had already queued, and the unhandled error surfaces one event-loop turn later than before.

**Почему:** Kotlin has no failure-path release to copy the ordering from, so the port has to choose one. Keeping the whole `withContext` resumption on a single queue is what makes the success ordering correct in the first place; splitting the two outcomes across a microtask and an event task would reintroduce the same class of inversion for `onTaskFinished` and would make `awaitAll()` complete with the error before the progress callbacks it queued had run. The pre-existing `feedback.the-task-progress-bar-never-hides-again#1` guarantees (counter released, listeners told, exception still loud) are unchanged and still asserted by task_runner_failure_test.dart.

**Дата:** 2026-08-24

## Отложенное напоминание на своё время запоминается

**Что в оригинале:** ReminderController.onSnoozeTimePicked calls reminderScheduler.scheduleAtTime(habit, time), which writes nothing, then notificationTray.cancel(habit). On Android the cancel is NotificationManagerCompat.cancel(id) and cannot reach the AlarmManager alarm, so the one-off alarm survives un-recorded; only a later scheduleAll() -- after a command, an app start or a reboot -- silently replaces it with the habit's regular reminder (reminders.snooze-custom-time#2).

**Что делаем:** onSnoozeTimePicked calls ReminderSchedulerApi.snoozeUntil(habit, time), which writes the instant with WidgetPreferences.setSnoozeTime and then schedule(habit). Every later scheduleAll() re-arms that instant until it is in the past, at which point ReminderScheduler.schedule discards it exactly as it discards an expired delayed snooze.

**Почему:** This port has no fire-time hook: FlutterAlarmScheduler files the finished notification as the alarm under reminderNotificationId(habit), the same id the core tray cancels, and flutter_local_notifications' cancel drops the pending scheduled notification as well as the posted one. FlutterNotificationTray.removeNotification therefore re-arms with scheduleAll() to make up for that (audit3.recording-a-non-completing-entry-silently#1) -- and onSnoozeTimePicked's own cancel runs that re-arm inside the same user action. An un-recorded instant cannot survive its own snooze, so reproducing Kotlin exactly leaves the entire 'Later -> Custom...' branch inert and silently drops the user's choice. Deleting the re-arm instead would be worse: the cancel would still disarm the custom alarm and nothing would replace it. Persisting is the only repair that is robust to the ordering of the tray's and the scheduler's independent call queues.

**Дата:** 2026-08-24


## Подсветка фокуса строки привычки

**Что в оригинале:** HabitCardListView.bindCardView binds the card with setOnTouchListener + GestureDetector and never setOnClickListener, so HabitCardView's FOCUSABLE_AUTO resolves to not-focusable: the row is never a Tab/D-pad stop and can never draw a focus highlight under any circumstances.

**Что делаем:** Keeps the row-level InkWell focusable (the deviation already recorded under audit10.the-check-mark-grid-cannot-be-reached-or#1, so Enter on a row opens the detail screen) and gives it a Theme.focusColor tint while `_rowFocusNode.hasPrimaryFocus` is true. The descendant-driven flood is gone; the row-own highlight remains.

**Почему:** Deleting the row's highlight along with the flood would leave a keyboard stop with no visible indicator, i.e. an access path the user cannot see. The recorded deviation is that the row is reachable; an unlabelled, unpainted stop would be worse than either side.

**Дата:** 2026-08-24


## Выбранный пункт в списковых диалогах настроек

**Что в оригинале:** setSingleChoiceItems inflates select_dialog_singlechoice_material — a CheckedTextView whose radio indicator is tinted with ?colorControlActivated while the label keeps its ordinary text colour.

**Что делаем:** `ListTile(selected: true)` resolves both the title text and the trailing check Icon to ColorScheme.primary, so the label is tinted too.

**Почему:** ListTile has no way to publish SemanticsFlag.isSelected without also entering its selected visual state, and wrapping it in an outer Semantics leaves the ListTile's own node still saying `selected: false` — which is the defect. The tint is the idiomatic Flutter rendering of the same 'this one is checked' state upstream renders with a tinted radio; no rule or screenshot pins the label colour.

**Дата:** 2026-08-24


## Одно сообщение LONG_PRESS вместо двух

**Что в оригинале:** CheckmarkButtonView.performToggle calls performHapticFeedback(LONG_PRESS) explicitly at CheckmarkButtonView.kt:98, and then View.performLongClickInternal fires the same constant again because onLongClick returned true — two coincident LONG_PRESS ticks.

**Что делаем:** Fires exactly one. `performLongPressFeedback()` is wired only to the editor branch of the long press; the toggle branch keeps the single `performToggleFeedback()` it already had.

**Почему:** Two identical LONG_PRESS ticks back to back are one buzz perceptually, and audit3's assertion at checkmark_haptics_test.dart:135 already pins hasLength(1). Stacking a second platform message would change nothing a user can feel while breaking that pin for the wrong reason. Guarded by a new test ('the default boolean long press still buzzes exactly once').

**Дата:** 2026-08-24


## Отдача при долгом нажатии на iOS и macOS

**Что в оригинале:** performHapticFeedback(HapticFeedbackConstants.LONG_PRESS) — Android only.

**Что делаем:** performLongPressFeedback() switches on defaultTargetPlatform exactly as performToggleFeedback() already did: HapticFeedback.vibrate() on Android/fuchsia/linux/windows, HapticFeedback.mediumImpact() on iOS/macOS.

**Почему:** Extends the already-recorded feedback.checkmark-haptics-are-the-ios-alert-buzz#1 deviation to the new call site — a typeless vibrate reaches iOS as kSystemSoundID_Vibrate, a third of a second of whole-device alert buzz, for what upstream means as a tick.

**Дата:** 2026-08-24

## Пропущенное за время выключения напоминание

**Что в оригинале:** ReminderReceiver's BOOT_COMPLETED branch calls ReminderController.onBootCompleted() = reminderScheduler.scheduleAll(), which recomputes every habit's alarm from DateUtils.getUpcomingTimeInMillis(hour, minute). The missed occurrence is silently lost AND the next upcoming occurrence is armed, all without the app being opened.

**Что делаем:** ReminderBootReceiver drops the elapsed cache entries and re-arms only the entries that are still in the future; the chain for a habit whose alarm elapsed resumes at the next scheduleAll(), which AppScope.boot() runs at every app start and ReminderScheduler.onCommandFinished after every command. So a user who reboots across a reminder and then never opens the app misses the following day's reminder too.

**Почему:** In this port the alarm IS the finished notification (no fire-time hook), so 'recompute the next occurrence' cannot be done from a boot receiver without re-running the whole ReminderNotificationBuilder — including the show-gates and the payload's checkmark day — in Kotlin. Advancing the stale entry instead of dropping it would deliver a notification whose `when` line and payload still name the old day, i.e. it would write entries to a past day. Dropping is the same outcome the user sees upstream for the missed reminder itself, and it removes the data-losing half of the defect; the residual gap only costs a later reminder for a user who reboots and then never opens the app.

**Дата:** 2026-08-24


## Минимум одна колонка в графике счёта виджета

**Что в оригинале:** `nColumns = (width / columnWidth).toInt()` with no lower bound, followed by `columnWidth = width.toFloat() / nColumns`. On a widget narrower than one column that is 0, and the division that follows yields Infinity/NaN.

**Что делаем:** `val nColumns = max(1, (width / columnWidth).toInt())`, the same guard the port's iOS Score widget already uses (`let nColumns = max(1, Int(width / columnWidth))`).

**Почему:** A home-screen widget is resized by the user and no launcher guarantees a minimum width; an Infinity column width would blank the chart. The guard changes nothing at any reachable size — the default 300x300 px square still yields the same column count as upstream.

**Дата:** 2026-08-24

## Отложенное нажатие на виджете применяется к своему дню

**Что в оригинале:** The tap is an ACTION_TOGGLE_REPETITION broadcast handled the instant the finger lifts, inside the app's own process, and it carries no timestamp: `IntentParser.parseDate` supplies `getToday()`. A widget toggle therefore always lands on the day the app is currently on.

**Что делаем:** The extension cannot run Dart, so the write is deferred to the app's next publish; the queue entry carries the day the card was drawing when it was tapped, and `_apply` uses that day even when `getToday()` has since moved on. Only the future is refused. A test (`#1 a tap dated before today still lands on its own day`) pins this.

**Почему:** It is the closest reachable behaviour, and the alternative loses data. Clamping a past date to `getToday()` would move a tick the user made on Monday — and watched the card answer on Monday — onto Tuesday, leaving Monday blank and Tuesday marked without being asked. The deferral is already a documented port-wide deviation (`WidgetToggleQueue`: "for as long as the app stays closed, the flipped card is a promise rather than a record"); this is the day-arithmetic consequence of it.

**Дата:** 2026-08-24


## Формат часа следует локали устройства

**Что в оригинале:** android.text.format.DateFormat.getTimeFormat(context) builds its pattern from ICU's getBestDateTimePattern(configurationLocale, is24HourFormat ? "Hm" : "hm"). The "hm" skeleton FORCES a 12-hour rendering, so a de or ja device whose owner has switched the system 24-hour setting off shows "8:30 AM" / "午前8:30".

**Что делаем:** formatDeviceTime uses intl.DateFormat.Hm(locale) for the 24-hour branch and intl.DateFormat.jm(locale) for the 12-hour one. `package:intl` (and flutter_localizations' bundled pattern table) carries no forced-12-hour "hm" skeleton — only "j", the locale's PREFERRED hour cycle. So on a locale whose CLDR preference is 24-hour, use24HourFormat: false keeps that locale's 24-hour pattern instead of switching to "h:mm a".

**Почему:** The data to do better is not on the device: no Dart package ships the CLDR "hm" best-pattern table, and inventing one ('replace H with h and append the AM/PM marker') gets CJK locales visibly wrong — ja's real "hm" pattern is "aK:mm" ("午前8:30"), while the naive derivation yields "8:30 午前". Flutter's own MaterialLocalizations.formatTimeOfDay reads alwaysUse24HourFormat:false exactly the same way, so the Edit screen already behaved like this. The divergence needs the user to have overridden the system 12/24 setting away from their locale's default; in every other configuration the two agree, and the reported defect (an en-US pattern in all 47 languages) is gone either way.

**Дата:** 2026-08-24

## Заголовок диалога выбора времени напоминания

**Что в оригинале:** EditHabitActivity opens a vendored AOSP radial TimePickerDialog in the same Activity context, so the dialog header and the row both render in the configuration (device) locale.

**Что делаем:** The port substitutes Flutter's showTimePicker (already a documented substitution in the file header, because the radial dialog has no Flutter equivalent), and its header renders through MaterialLocalizations — i.e. Localizations.localeOf. So on an en-AU device the row now reads "8:30 am" (correct) while the picker header reads "8:30 AM".

**Почему:** Driving the substitute dialog's header would mean wrapping showTimePicker in a Localizations.override for the device locale, which would also swap the dialog's OK/Cancel strings and semantics labels out of the app's UI language — a bigger divergence than the one it removes. The row is the surface edit-habit.reminder-time#8 names (populateReminder's label) and the one that has to agree with the Show-habit subtitle card. Recorded in the _formatTime doc comment as a known divergence.

**Дата:** 2026-08-24

## Пересчёт текстов уведомлений при смене языка

**Что в оригинале:** Nothing. AndroidNotificationTray.buildNotification reads all six strings out of the application Context at fire time (getString(R.string.yes/.no/.enter/.snooze/.default_reminder_question)) and showNotification calls createAndroidNotificationChannel(context) — which reads R.string.reminder — before every notify(). Resources.getString resolves against the process's current configuration, so the very next reminder is already translated with nothing to re-arm. There is no iOS half.

**Что делаем:** _ThemedAppState.didChangeLocales calls AppScope.onLocalesChanged(), which (1) re-creates the Android REMINDERS channel from the freshly-resolved name, (2) re-registers the Darwin notification categories by calling the plugin's platform-specific initialize() again with the same settings and callbacks (every request*Permission is false, so nothing is prompted), and (3) calls scheduler.scheduleAll() to re-arm every alarm.

**Почему:** Two port-only facts force it. The port has no fire-time hook — the alarm IS the finished notification (already recorded in DEVIATIONS.md) — so the copy is written in at schedule time and only a re-arm can replace it. And flutter_local_notifications takes the channel name and the Darwin category titles once, at initialize(), where Android's own API is called before every post; re-resolving the builder's strings alone would leave the channel name in system settings and the iOS action buttons frozen until reinstall. The net user-visible behaviour is upstream's: the next reminder after a language change is in the new language.

**Дата:** 2026-08-24
