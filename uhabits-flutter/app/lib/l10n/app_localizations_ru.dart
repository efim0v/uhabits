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
  String get sleepLastNight => 'Прошлая ночь';

  @override
  String get sleepBedtime => 'Отбой';

  @override
  String get sleepWakeTime => 'Подъём';

  @override
  String get sleepDuration => 'Сон';

  @override
  String get sleepNights => 'Ночи';

  @override
  String get sleepStability => 'Стабильность';

  @override
  String get sleepNoData => 'Данных пока нет';

  @override
  String sleepSpreadMinutes(String minutes) {
    return '±$minutes мин';
  }

  @override
  String sleepSkippedCount(int skipped, int days) {
    return 'Пропущено дней: $skipped из $days';
  }

  @override
  String get sleepMarkSkipped => 'Отметить';

  @override
  String sleepLastSkipped(String date) {
    return 'Последний: $date';
  }

  @override
  String get sleepWeakestSleep =>
      'Легли и встали вовремя, но спали меньше цели.';

  @override
  String get sleepWeakestBed =>
      'Выспались и встали вовремя, но легли не по расписанию.';

  @override
  String get sleepWeakestWake =>
      'Выспались и легли вовремя, но встали не по расписанию.';

  @override
  String get sleepPerfectNight => 'По расписанию и выспались.';

  @override
  String get sleepQuestionExample => 'напр.: Как вы спали прошлой ночью?';

  @override
  String get sleepSkipThisDay => 'Пропустить этот день';

  @override
  String get sleepSkipExplained =>
      'Записано, но не засчитывается ни в плюс, ни в минус.';

  @override
  String get sleepTargetBedtime => 'Целевой отбой';

  @override
  String get sleepTargetWakeTime => 'Целевой подъём';

  @override
  String get sleepMinimumSleep => 'Минимум сна';

  @override
  String get sleepHomeTimezone => 'Домашний часовой пояс';

  @override
  String get sleepAdaptationRate => 'Адаптация';

  @override
  String sleepAdaptationPerDay(int minutes) {
    return '$minutes мин в день';
  }

  @override
  String get sleepEnterNight => 'Ввести ночь';

  @override
  String get sleepActuallyAsleep => 'Фактически спали';

  @override
  String get sleepHealthAccess => 'Разрешить доступ к Здоровью';

  @override
  String get sleepHealthDenied =>
      'Без доступа к Здоровью ночи придётся вводить вручную.';

  @override
  String sleepSuggestGoalBed(String time) {
    return 'Вы ложитесь около $time. Сдвинуть цель?';
  }

  @override
  String sleepSuggestGoalWake(String time) {
    return 'Вы встаёте около $time. Сдвинуть цель?';
  }

  @override
  String get sleepSuggestSkip =>
      'Часовой пояс изменился. Отметить эти дни пропущенными?';

  @override
  String get sleepSuggestApply => 'Сдвинуть';

  @override
  String get sleepSuggestDismiss => 'Не сейчас';

  @override
  String get sleepSkipped => 'Пропущено';

  @override
  String get sleepHabitType => 'Сон';

  @override
  String get sleepHabitTypeExample =>
      'напр.: Ложиться в 23:00, вставать в 07:00 и спать не меньше 7:30 — оценивается по данным Здоровья или вводится вручную.';

  @override
  String get sleepAdvanced => 'Дополнительно';

  @override
  String get sleepWeightSleep => 'Вес: сон';

  @override
  String get sleepWeightBed => 'Вес: отбой';

  @override
  String get sleepWeightWake => 'Вес: подъём';

  @override
  String get sleepHalfCreditTime => 'Половина зачёта (время)';

  @override
  String get sleepHalfCreditSleep => 'Половина зачёта (сон)';

  @override
  String sleepMinutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String sleepTimezoneOffset(String sign, String hours, String minutes) {
    return 'UTC$sign$hours:$minutes';
  }

  @override
  String get abstinenceHabitType => 'Воздержание';

  @override
  String get abstinenceHabitTypeExample =>
      'напр.: Не пить. Не листать ленту. Молчание — чистый день; отмечать нужно только срывы.';

  @override
  String get abstinenceQuestionExample => 'напр.: Вы сорвались сегодня?';

  @override
  String get abstinenceAllowance => 'Допуск';

  @override
  String get abstinenceAllowanceExample => 'напр.: 30';

  @override
  String get abstinenceAllowanceUnit => 'Ед. изм.';

  @override
  String get abstinenceAllowanceUnitExample => 'напр.: минуты';

  @override
  String get abstinenceCommittedFrom => 'Обязательство с';

  @override
  String get abstinenceTitle => 'Без срывов';

  @override
  String abstinenceSince(String date) {
    return 'С $date';
  }

  @override
  String abstinenceLastLapse(String date) {
    return 'Последний срыв: $date';
  }

  @override
  String get abstinenceLapseToday => 'Отметить срыв';

  @override
  String get abstinenceUndoToday => 'Отменить срыв';

  @override
  String abstinenceAmountPrompt(String allowance, String unit) {
    return 'Не более $allowance $unit в день';
  }

  @override
  String abstinenceAmountPromptNoUnit(String allowance) {
    return 'Не более $allowance в день';
  }

  @override
  String abstinenceDurationYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа',
      many: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String get abstinenceOfRecord => 'от рекорда';

  @override
  String get abstinenceOfPrevious => 'от прошлой серии';

  @override
  String get abstinenceIsRecord => 'рекорд';

  @override
  String get abstinenceLapsesTotal => 'срывов';
}
