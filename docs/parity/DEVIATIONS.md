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

**Что в оригинале:** при срабатывании будильника выполняется Dart-код, который показывает
уведомление и тут же перепланирует следующее; после перезагрузки `BOOT_COMPLETED` запускает
`scheduleAll()`.

**Что сделано:** уведомления планируются заранее через `flutter_local_notifications` с
привязкой к часовому поясу. Собственный приёмник плагина восстанавливает их после
перезагрузки Android, а на iOS запланированные уведомления переживают перезагрузку сами.

**Чего не хватает, честно:** в момент срабатывания никакой Dart-код не выполняется, поэтому
цепочка «показал — перепланировал» отсутствует; будильники держатся тем, что `scheduleAll()`
вызывается при старте приложения и после каждой команды. Отложенное напоминание, срок
которого истёк при выключенном устройстве, отбрасывается только при следующем запуске.

**Что нужно для полного паритета:** нативный `BroadcastReceiver` на Android и точка входа
фонового изолята. Это отдельная задача, помечена в `PROGRESS.md` как `BLOCKED`.

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

**Что меняется для пользователя:** none — the pattern behaviours (#1, #2, #5) are ported and cited, and the port is deliberately locale-independent where the JVM actual was not.

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

**Что меняется для пользователя:** One real one, small and specific: rule #2's sp-vs-dp distinction. Upstream's only spToPixels call is RingView's percentage text (uhabits-android/.../common/views/RingView.kt:87), which grew with the OS font-scale setting; the port paints that text on a canvas at a fixed logical size and `textScaler` appears nowhere in app/lib or packages/uhabits_core/lib, so it no longer scales. Every other upstream measurement was dp, which Flutter reproduces exactly.

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
