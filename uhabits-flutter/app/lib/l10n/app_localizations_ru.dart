// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class L10nRu extends L10n {
  L10nRu([String locale = 'ru']) : super(locale);

  @override
  String get overview => 'Обзор';

  @override
  String get appName => 'Трекер привычек Loop';

  @override
  String get mainActivityTitle => 'Привычки';

  @override
  String get actionSettings => 'Настройки';

  @override
  String get edit => 'Редактировать';

  @override
  String get delete => 'Удалить';

  @override
  String get archive => 'Архивировать';

  @override
  String get unarchive => 'Вернуть из архива';

  @override
  String get addHabit => 'Добавить привычку';

  @override
  String get colorPickerDefaultTitle => 'Изменить цвет';

  @override
  String get toastHabitCreated => 'Привычка создана';

  @override
  String get habitStrength => 'Сила привычки';

  @override
  String get history => 'История';

  @override
  String get clear => 'Очистить';

  @override
  String get reminder => 'Напоминание';

  @override
  String get save => 'Сохранить';

  @override
  String get streaks => 'Рекорды';

  @override
  String get noHabitsFound => 'У вас нет активных привычек';

  @override
  String get noHabitsLeftToDo => 'Вы закончили на сегодня!';

  @override
  String get longPressToToggle =>
      'Нажмите и удерживайте, чтобы установить или снять галочку';

  @override
  String get reminderOff => 'Выкл';

  @override
  String get createHabit => 'Добавить привычку';

  @override
  String get editHabit => 'Изменить привычку';

  @override
  String get check => 'Отметить';

  @override
  String get snooze => 'Отложить';

  @override
  String get introTitle1 => 'Добро пожаловать';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker помогает вам заводить и поддерживать полезные привычки.';

  @override
  String get introTitle2 => 'Добавьте несколько привычек';

  @override
  String get introDescription2 =>
      'Каждый день, после выполнения вашей привычки, поставьте галочку в приложении.';

  @override
  String get introTitle4 => 'Отслеживайте свои успехи';

  @override
  String get introDescription4 =>
      'Детализированные диаграммы демонстрируют, как ваши привычки улучшились со временем.';

  @override
  String get interval15Minutes => '15 минут';

  @override
  String get interval30Minutes => '30 минут';

  @override
  String get interval1Hour => '1 час';

  @override
  String get interval2Hour => '2 часа';

  @override
  String get interval4Hour => '4 часа';

  @override
  String get interval8Hour => '8 часов';

  @override
  String get interval24Hour => '24 часа';

  @override
  String get intervalAlwaysAsk => 'Всегда спрашивать';

  @override
  String get intervalCustom => 'Настроить...';

  @override
  String get prefToggleTitle => 'Отмечать коротким нажатием';

  @override
  String get prefToggleDescription2 =>
      'Галочки в одно касание вместо нажатия и удержания';

  @override
  String get prefRateThisApp => 'Оценить приложение в Google Play';

  @override
  String get prefSendFeedback => 'Отправить сообщение разработчику';

  @override
  String get prefViewSourceCode => 'Посмотреть исходный код на GitHub';

  @override
  String get links => 'Ссылки';

  @override
  String get name => 'Название';

  @override
  String get settings => 'Настройки';

  @override
  String get selectSnoozeDelay => 'Задержка повтора';

  @override
  String get hintTitle => 'А вы знали?';

  @override
  String get hintDrag =>
      'Чтобы поменять порядок записей, нажмите и удерживайте название записи, затем перетащите её на нужное место.';

  @override
  String get hintLandscape =>
      'В горизонтальном режиме отображается больше дней.';

  @override
  String get habitNotFound => 'Привычка удалена / не найдена';

  @override
  String get weekends => 'По выходным';

  @override
  String get anyWeekday => 'По будням';

  @override
  String get anyDay => 'Каждый день';

  @override
  String get selectWeekdays => 'Выберите дни';

  @override
  String get exportToCsv => 'Экспортировать как CSV';

  @override
  String get doneLabel => 'Готово';

  @override
  String get clearLabel => 'Очистить';

  @override
  String get selectHours => 'Выберите часы';

  @override
  String get selectMinutes => 'Выберите минуты';

  @override
  String get about => 'О приложении';

  @override
  String get translators => 'Переводчики';

  @override
  String get developers => 'Разработчики';

  @override
  String versionN(String p1) {
    return 'Версия $p1';
  }

  @override
  String get frequency => 'Частота';

  @override
  String get checkmark => 'Галочка';

  @override
  String get checkmarkStackWidget => 'Checkmark Stack Widget';

  @override
  String get frequencyStackWidget => 'Frequency Stack Widget';

  @override
  String get scoreStackWidget => 'Score Stack Widget';

  @override
  String get historyStackWidget => 'History Stack Widget';

  @override
  String get streaksStackWidget => 'Streaks Stack Widget';

  @override
  String get bestStreaks => 'Лучшие серии';

  @override
  String get everyDay => 'Каждый день';

  @override
  String get everyWeek => 'Каждую неделю';

  @override
  String get help => 'Помощь и FAQ';

  @override
  String get couldNotExport => 'Ошибка экспорта данных.';

  @override
  String get couldNotImport => 'Ошибка импорта данных.';

  @override
  String get fileNotRecognized => 'Невозможно определить тип файла.';

  @override
  String get habitsImported => 'Привычки успешно импортированы.';

  @override
  String get importData => 'Импортировать данные';

  @override
  String get exportFullBackup => 'Экспортировать полную резервную копию';

  @override
  String get importDataSummary =>
      'Поддерживает полные резервные копии, экспортированные из этого приложения, а также файлы, сгенерированные приложениями Tickmate, HabitBull и Rewire. Подробнее смотрите в FAQ.';

  @override
  String get exportAsCsvSummary =>
      'Генерирует файлы, которые можно открыть в ПО для работы с таблицами (таком как Microsoft Excel или OpenOffice Calc). Этот файл нельзя импортировать обратно.';

  @override
  String get exportFullBackupSummary =>
      'Генерирует файл, который содержит все ваши данные. Этот файл можно импортировать обратно.';

  @override
  String get selectPublicBackupFolder =>
      'Выбрать публичную папку для резервных копий';

  @override
  String get noPublicBackupFolderSelected => 'Папка не выбрана';

  @override
  String get bugReportFailed => 'Ошибка генерации отчёта об ошибке.';

  @override
  String get generateBugReport => 'Сгенерировать отчёт об ошибке';

  @override
  String get troubleshooting => 'Устранение неполадок';

  @override
  String get helpTranslate => 'Помогите перевести это приложение';

  @override
  String get nightMode => 'Ночной режим';

  @override
  String get usePureBlack => 'Использовать подлинный чёрный в ночном режиме';

  @override
  String get pureBlackDescription =>
      'Заменяет серый фон на подлинный чёрный в ночном режиме. Сокращает расход батареи в телефонах с дисплеем AMOLED.';

  @override
  String get interfacePreferences => 'Интерфейс';

  @override
  String get reverseDays => 'Обратный порядок дней';

  @override
  String get reverseDaysDescription =>
      'Показывать дни в обратном порядке на главном экране';

  @override
  String get day => 'День';

  @override
  String get week => 'Неделя';

  @override
  String get month => 'Месяц';

  @override
  String get quarter => 'Квартал';

  @override
  String get year => 'Год';

  @override
  String get total => 'Всего';

  @override
  String get yesOrNo => 'Да или Нет';

  @override
  String everyXDays(int p1) {
    return 'Каждые $p1 дней';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Каждые $p1 недель';
  }

  @override
  String get score => 'Результат';

  @override
  String get reminderSound => 'Звук напоминания';

  @override
  String get none => 'Без звука';

  @override
  String get filter => 'Фильтр';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Скрыть завершённые';

  @override
  String get hideEntered => 'Скрыть введённые';

  @override
  String get hideArchived => 'Скрыть архивированные';

  @override
  String get stickyNotifications => 'Сделать уведомления \"липкими\"';

  @override
  String get stickyNotificationsDescription =>
      'Предотвращает смахивание уведомлений.';

  @override
  String get ledNotifications => 'Световая индикация';

  @override
  String get ledNotificationsDescription =>
      'Мигать индикатором для напоминаний. Доступно только в телефонах со светодиодным индикатором событий.';

  @override
  String get repairDatabase => 'Исправить базу данных';

  @override
  String get databaseRepaired => 'База данных исправлена.';

  @override
  String get uncheck => 'Снять отметку';

  @override
  String get toggle => 'Переключить';

  @override
  String get action => 'Действие';

  @override
  String get habit => 'Привычка';

  @override
  String get sort => 'Сортировка';

  @override
  String get manually => 'Вручную';

  @override
  String get byName => 'По названию';

  @override
  String get byColor => 'По цвету';

  @override
  String get byScore => 'По результату';

  @override
  String get byStatus => 'По статусу';

  @override
  String get export => 'Экспортировать';

  @override
  String get longPressToEdit =>
      'Нажмите и удерживайте, чтобы изменить значение';

  @override
  String get value => 'Значение';

  @override
  String get calendar => 'Календарь';

  @override
  String get unit => 'Ед. изм.';

  @override
  String get targetType => 'Тип цели';

  @override
  String get targetTypeAtLeast => 'Не меньше';

  @override
  String get targetTypeAtMost => 'Не больше';

  @override
  String get exampleQuestionBoolean => 'напр.: Вы упражнялись сегодня?';

  @override
  String get question => 'Вопрос';

  @override
  String get target => 'Цель';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get customizeNotificationSummary =>
      'Настройка параметров уведомлений: звук, вибрация, свет и др.';

  @override
  String get customizeNotification => 'Настройка уведомлений';

  @override
  String get prefViewPrivacy => 'Посмотреть политику конфиденциальности';

  @override
  String get viewAllContributors => 'Посмотреть всех участников…';

  @override
  String get database => 'База данных';

  @override
  String get widgetOpacityTitle => 'Непрозрачность виджета';

  @override
  String get widgetOpacityDescription =>
      'Делает виджеты более прозрачными или непрозрачными на главном экране.';

  @override
  String get firstDayOfTheWeek => 'Первый день недели';

  @override
  String get defaultReminderQuestion => 'Вы выполнили эту привычку сегодня?';

  @override
  String get notes => 'Заметки';

  @override
  String get exampleNotes => '(Необязательно)';

  @override
  String get yesOrNoExample =>
      'Например, вы рано проснулись сегодня? Вы занимались спортом? Вы играли в шахматы?';

  @override
  String get measurable => 'Измеримый';

  @override
  String get measurableExample =>
      'напр.: Сколько км вы пробежали сегодня? Сколько страниц прочитали?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 раз в неделю';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 раз в месяц';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 раз в $p2 дней';
  }

  @override
  String get yesOrNoShortExample => 'напр.: Поупражняться';

  @override
  String get color => 'Цвет';

  @override
  String get exampleTarget => 'напр.: 15';

  @override
  String get measurableShortExample => 'напр.: Побегать';

  @override
  String get measurableQuestionExample =>
      'напр.: Сколько км вы пробежали сегодня?';

  @override
  String get measurableUnitsExample => 'напр.: км';

  @override
  String get everyMonth => 'Каждый месяц';

  @override
  String get validationCannotBeBlank => 'Не может быть пустым';

  @override
  String get today => 'Сегодня';

  @override
  String get enter => 'Ввести';

  @override
  String get noHabits => 'Привычек не найдено';

  @override
  String get noNumericalHabits => 'Измеримых привычек не найдено';

  @override
  String get noBooleanHabits => 'Привычек \"да или нет\" не найдено';

  @override
  String get increment => 'Увеличить';

  @override
  String get decrement => 'Уменьшить';

  @override
  String get prefSkipTitle => 'Включить пропуск дней';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Переключите дважды, чтобы добавить пропуск вместо галочки. Пропуски сохраняют ваш результат неизменным и не прерывают серию.';

  @override
  String get prefUnknownTitle =>
      'Показывать вопросительные знаки при отсутствии данных';

  @override
  String get prefUnknownDescription =>
      'Отличать дни без данных от фактических пропусков. Чтобы ввести пропуск, переключите дважды.';

  @override
  String get youAreNowADeveloper => 'Теперь вы разработчик';

  @override
  String get activityNotFound =>
      'Не найдено приложения для обработки данного действия';

  @override
  String get prefMidnightDelayTitle =>
      'Продлить день на несколько часов после полуночи';

  @override
  String get prefMidnightDelayDescription =>
      'Подождать до 3:00 перед показом нового дня. Полезно, если вы обычно ложитесь спать после полуночи. Требуется перезапуск приложения.';

  @override
  String get prefAnimationsTitle => 'Disable animations';

  @override
  String get prefAnimationsDescription =>
      'Disable confetti animation after adding a checkmark.';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Привычки изменены',
      many: 'Привычки изменены',
      few: 'Привычки изменены',
      one: 'Привычка изменена',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Привычки удалены',
      many: 'Привычки удалены',
      few: 'Привычки удалены',
      one: 'Привычка удалена',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Привычки архивированы',
      many: 'Привычки архивированы',
      few: 'Привычки архивированы',
      one: 'Привычка архивирована',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Привычки возвращены из архива',
      many: 'Привычки возвращены из архива',
      few: 'Привычки возвращены из архива',
      one: 'Привычка возвращена из архива',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить привычки?',
      many: 'Удалить привычки?',
      few: 'Удалить привычки?',
      one: 'Удалить привычку?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Привычки будут удалены. Это действие невозможно отменить.',
      many: 'Привычки будут удалены. Это действие невозможно отменить.',
      few: 'Привычки будут удалены. Это действие невозможно отменить.',
      one: 'Привычка будет удалена. Это действие невозможно отменить.',
    );
    return '$_temp0';
  }

  @override
  String get sleepLastNight => 'Last night';

  @override
  String get sleepBedtime => 'Bedtime';

  @override
  String get sleepWakeTime => 'Wake time';

  @override
  String get sleepDuration => 'Sleep';

  @override
  String get sleepNights => 'Nights';

  @override
  String get sleepStability => 'Stability';

  @override
  String get sleepNoData => 'No data yet';

  @override
  String sleepSpreadMinutes(String minutes) {
    return '±$minutes min';
  }

  @override
  String sleepSkippedCount(int skipped, int days) {
    return '$skipped of $days days skipped';
  }

  @override
  String get sleepMarkSkipped => 'Mark';

  @override
  String sleepLastSkipped(String date) {
    return 'Last: $date';
  }

  @override
  String get sleepWeakestSleep =>
      'Went to bed and got up on time, but slept less than the goal.';

  @override
  String get sleepWeakestBed =>
      'Slept enough and got up on time, but went to bed off schedule.';

  @override
  String get sleepWeakestWake =>
      'Slept enough and went to bed on time, but got up off schedule.';

  @override
  String get sleepPerfectNight => 'On schedule and slept enough.';

  @override
  String get sleepTargetBedtime => 'Target bedtime';

  @override
  String get sleepTargetWakeTime => 'Target wake time';

  @override
  String get sleepMinimumSleep => 'Minimum sleep';

  @override
  String get sleepHomeTimezone => 'Home time zone';

  @override
  String get sleepAdaptationRate => 'Adaptation';

  @override
  String sleepAdaptationPerDay(int minutes) {
    return '$minutes min per day';
  }

  @override
  String get sleepEnterNight => 'Enter night';

  @override
  String get sleepActuallyAsleep => 'Actually asleep';

  @override
  String get sleepHealthAccess => 'Allow access to Health';

  @override
  String get sleepHealthDenied =>
      'Without access to Health, nights have to be entered by hand.';

  @override
  String sleepSuggestGoalBed(String time) {
    return 'You have been going to bed around $time. Move the goal?';
  }

  @override
  String sleepSuggestGoalWake(String time) {
    return 'You have been getting up around $time. Move the goal?';
  }

  @override
  String get sleepSuggestSkip =>
      'Your time zone changed. Mark these days as skipped?';

  @override
  String get sleepSuggestApply => 'Move';

  @override
  String get sleepSuggestDismiss => 'Not now';

  @override
  String get sleepSkipped => 'Skipped';

  @override
  String get sleepHabitType => 'Sleep';

  @override
  String get sleepHabitTypeExample =>
      'e.g. Go to bed at 23:00, get up at 07:00, and sleep at least 7:30 — scored from Health or entered by hand.';

  @override
  String get sleepAdvanced => 'Advanced';

  @override
  String get sleepWeightSleep => 'Weight: sleep';

  @override
  String get sleepWeightBed => 'Weight: bedtime';

  @override
  String get sleepWeightWake => 'Weight: wake time';

  @override
  String get sleepHalfCreditTime => 'Half credit at (times)';

  @override
  String get sleepHalfCreditSleep => 'Half credit at (sleep)';

  @override
  String sleepMinutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimezoneOffset(String sign, String hours, String minutes) {
    return 'UTC$sign$hours:$minutes';
  }
}
