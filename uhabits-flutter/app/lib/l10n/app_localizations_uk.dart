// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class L10nUk extends L10n {
  L10nUk([String locale = 'uk']) : super(locale);

  @override
  String get overview => 'Огляд';

  @override
  String get appName => 'Трекер звичок Loop';

  @override
  String get mainActivityTitle => 'Звички';

  @override
  String get actionSettings => 'Налаштування';

  @override
  String get edit => 'Змінити';

  @override
  String get delete => 'Вилучити';

  @override
  String get archive => 'Архівувати';

  @override
  String get unarchive => 'Розархівувати';

  @override
  String get addHabit => 'Додати звичку';

  @override
  String get colorPickerDefaultTitle => 'Змінити колір';

  @override
  String get toastHabitCreated => 'Звичку створено';

  @override
  String get habitStrength => 'Сила звички';

  @override
  String get history => 'Історія';

  @override
  String get clear => 'Очистити';

  @override
  String get reminder => 'Нагадування';

  @override
  String get save => 'Зберегти';

  @override
  String get streaks => 'Серії';

  @override
  String get noHabitsFound => 'У Вас немає активних звичок';

  @override
  String get noHabitsLeftToDo => 'На сьогодні все!';

  @override
  String get longPressToToggle =>
      'Натисніть та утримуйте, щоб встановити або зняти пташку';

  @override
  String get reminderOff => 'Вимкнути';

  @override
  String get createHabit => 'Додати звичку';

  @override
  String get editHabit => 'Змінити звичку';

  @override
  String get check => 'Відзначити';

  @override
  String get snooze => 'Відкласти';

  @override
  String get introTitle1 => 'Вітаємо';

  @override
  String get introDescription1 =>
      'Трекер звичок Loop допомагає Вам розвивати і підтримувати корисні звички.';

  @override
  String get introTitle2 => 'Додайте нові звички';

  @override
  String get introDescription2 =>
      'Щодня, після виконання Вашої звички, ставте пташку в програмі.';

  @override
  String get introTitle4 => 'Відстежуйте свій поступ';

  @override
  String get introDescription4 =>
      'Деталізовані хвилеписи демонструють, як Ваші звички покращилися з часом.';

  @override
  String get interval15Minutes => '15 хвилин';

  @override
  String get interval30Minutes => '30 хвилин';

  @override
  String get interval1Hour => '1 година';

  @override
  String get interval2Hour => '2 години';

  @override
  String get interval4Hour => '4 години';

  @override
  String get interval8Hour => '8 годин';

  @override
  String get interval24Hour => '24 години';

  @override
  String get intervalAlwaysAsk => 'Завжди запитувати';

  @override
  String get intervalCustom => 'Налаштувати...';

  @override
  String get prefToggleTitle => 'Відзначати коротким натисканням';

  @override
  String get prefToggleDescription2 =>
      'Встановлюйте відмітки одним натисканням замість натискання й утримування.';

  @override
  String get prefRateThisApp => 'Оцінити цю програму в Google Play';

  @override
  String get prefSendFeedback => 'Надіслати відгук розробникові';

  @override
  String get prefViewSourceCode => 'Подивитися вихідний код на GitHub';

  @override
  String get links => 'Посилання';

  @override
  String get name => 'Назва';

  @override
  String get settings => 'Налаштування';

  @override
  String get selectSnoozeDelay => 'Встановити повторне нагадування';

  @override
  String get hintTitle => 'Чи знаете ви, що?';

  @override
  String get hintDrag =>
      'Аби змінити порядок записів, натисніть і утримуйте назву запису, опісля перетягніть запис на потрібне місце.';

  @override
  String get hintLandscape =>
      'У ландшафтному режимі відображається більше днів.';

  @override
  String get habitNotFound => 'Звичку вилучено / не знайдено';

  @override
  String get weekends => 'У вихідні';

  @override
  String get anyWeekday => 'У будні';

  @override
  String get anyDay => 'Щодня';

  @override
  String get selectWeekdays => 'Оберіть дні';

  @override
  String get exportToCsv => 'Експортувати як CVS';

  @override
  String get doneLabel => 'Готово';

  @override
  String get clearLabel => 'Очистити';

  @override
  String get selectHours => 'Оберіть години';

  @override
  String get selectMinutes => 'Оберіть хвилини';

  @override
  String get about => 'Про програму';

  @override
  String get translators => 'Перекладачі';

  @override
  String get developers => 'Розробники';

  @override
  String versionN(String p1) {
    return 'Версія $p1';
  }

  @override
  String get frequency => 'Частота';

  @override
  String get checkmark => 'Пташка';

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
  String get bestStreaks => 'Найкращі серії';

  @override
  String get everyDay => 'Щодня';

  @override
  String get everyWeek => 'Щотижня';

  @override
  String get help => 'Допомога та ЧаПи';

  @override
  String get couldNotExport => 'Помилка експортування даних.';

  @override
  String get couldNotImport => 'Помилка імпортування даних.';

  @override
  String get fileNotRecognized => 'Неможливо визначити тип файлу.';

  @override
  String get habitsImported => 'Звички успішно імпортовано.';

  @override
  String get importData => 'Імпортувати дані';

  @override
  String get exportFullBackup => 'Експортувати повну резервну копію';

  @override
  String get importDataSummary =>
      'Підтримує імпортування повної резервної копії, експортованої цією програмою, а також файлів, створених програмами Tickmate, HabitBull та Rewire. Більше інформації дивіться у ЧаПи.';

  @override
  String get exportAsCsvSummary =>
      'Створює файли, які можна відкрити у програмах для роботи з таблицями (як-от: Microsoft Excel або OpenOffice Calc). Цей файл не можна імпортувати назад.';

  @override
  String get exportFullBackupSummary =>
      'Створює файл, що містить усі Ваші дані. Цей файл можна імпортувати назад.';

  @override
  String get selectPublicBackupFolder =>
      'Виберіть загальнодоступну теку для резервних копій';

  @override
  String get noPublicBackupFolderSelected => 'Теку не вибрано';

  @override
  String get bugReportFailed => 'Помилка створення звіту про помилку.';

  @override
  String get generateBugReport => 'Створити звіт про помилку';

  @override
  String get troubleshooting => 'Усунення несправностей';

  @override
  String get helpTranslate => 'Допоможіть перекласти цю програму';

  @override
  String get nightMode => 'Нічний режим';

  @override
  String get usePureBlack => 'Користати цілком чорне тло у нічному режимі';

  @override
  String get pureBlackDescription =>
      'Замінює сіре тло на цілком чорне у нічному режимі. Зменшує використання батареї в телефонах із дисплеєм AMOLED.';

  @override
  String get interfacePreferences => 'Оболонка';

  @override
  String get reverseDays => 'Зворотній лад днів';

  @override
  String get reverseDaysDescription =>
      'Показувати дні у зворотньому порядку на головному екрані';

  @override
  String get day => 'День';

  @override
  String get week => 'Тиждень';

  @override
  String get month => 'Місяць';

  @override
  String get quarter => 'Квартал';

  @override
  String get year => 'Рік';

  @override
  String get total => 'Усього';

  @override
  String get yesOrNo => 'Так або ні';

  @override
  String everyXDays(int p1) {
    return 'Кожні $p1 дні(-в)';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Кожні $p1 тижні(-в)';
  }

  @override
  String get score => 'Сталість';

  @override
  String get reminderSound => 'Звук нагадування';

  @override
  String get none => 'Немає';

  @override
  String get filter => 'Фільтр';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Приховати завершені';

  @override
  String get hideEntered => 'Приховати введені';

  @override
  String get hideArchived => 'Приховати архівовані';

  @override
  String get stickyNotifications => 'Закріпити сповіщення';

  @override
  String get stickyNotificationsDescription =>
      'Запобігає прихованню сповіщень.';

  @override
  String get ledNotifications => 'Світлове сповіщення';

  @override
  String get ledNotificationsDescription =>
      'Блимає для сповіщень. Доступне тільки в телефонах зі світловими LED-нагадуваннями.';

  @override
  String get repairDatabase => 'Відновити базу даних';

  @override
  String get databaseRepaired => 'Базу даних відновлено.';

  @override
  String get uncheck => 'Зняти позначку';

  @override
  String get toggle => 'Перемкнути';

  @override
  String get action => 'Дія';

  @override
  String get habit => 'Звичка';

  @override
  String get sort => 'Сортувати';

  @override
  String get manually => 'Самотужки';

  @override
  String get byName => 'За назвою';

  @override
  String get byColor => 'За кольором';

  @override
  String get byScore => 'За сталістю';

  @override
  String get byStatus => 'За станом';

  @override
  String get export => 'Експортувати';

  @override
  String get longPressToEdit => 'Натисніть і утримуйте, аби змінити значення';

  @override
  String get value => 'Значення';

  @override
  String get calendar => 'Календар';

  @override
  String get unit => 'Одиниця';

  @override
  String get targetType => 'Тип цілі';

  @override
  String get targetTypeAtLeast => 'Щонайменше';

  @override
  String get targetTypeAtMost => 'Щонайбільше';

  @override
  String get exampleQuestionBoolean => 'напр.: Ви робили сьогодні вправи?';

  @override
  String get question => 'Запитання';

  @override
  String get target => 'Мета';

  @override
  String get yes => 'Так';

  @override
  String get no => 'Ні';

  @override
  String get customizeNotificationSummary =>
      'Змінити звук, вібрацію, світло та інші налаштунки сповіщень';

  @override
  String get customizeNotification => 'Персональні налаштунки сповіщень';

  @override
  String get prefViewPrivacy => 'Переглянути політику конфіденційності';

  @override
  String get viewAllContributors => 'Переглянути всіх учасників…';

  @override
  String get database => 'База даних';

  @override
  String get widgetOpacityTitle => 'Прозорість віджета';

  @override
  String get widgetOpacityDescription =>
      'Робить віджети прозорішими, або більш видимими на вашому домашньому екрані.';

  @override
  String get firstDayOfTheWeek => 'Перший день тижня';

  @override
  String get defaultReminderQuestion => 'Ви вже виконали сьогодні цю звичку?';

  @override
  String get notes => 'Нотатки';

  @override
  String get exampleNotes => '(необов\'язково)';

  @override
  String get yesOrNoExample =>
      'напр., чи прокинулися сьогодні зрання? Чи виконали вправи? Або грали в шахи?';

  @override
  String get measurable => 'Вимірювальні';

  @override
  String get measurableExample =>
      'напр.: Скільки кілометрів ви сьогодні пробігли? Скільки сторінок прочитали?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 разів на тиждень';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 разів на місяць';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 разів за $p2 днів';
  }

  @override
  String get yesOrNoShortExample => 'напр., вправа';

  @override
  String get color => 'Колір';

  @override
  String get exampleTarget => 'напр., 15';

  @override
  String get measurableShortExample => 'напр., біг';

  @override
  String get measurableQuestionExample =>
      'напр., скільки кілометрів сьогодні пробігли?';

  @override
  String get measurableUnitsExample => 'напр., кілометри';

  @override
  String get everyMonth => 'Щомісяця';

  @override
  String get validationCannotBeBlank => 'Обов\'язкове поле';

  @override
  String get today => 'Сьогодні';

  @override
  String get enter => 'Увести';

  @override
  String get noHabits => 'Звичок не знайдено';

  @override
  String get noNumericalHabits => 'Вимірюваних звичок не знайдено';

  @override
  String get noBooleanHabits => 'Звичок так/ні не знайдено';

  @override
  String get increment => 'Збільшити';

  @override
  String get decrement => 'Зменшити';

  @override
  String get prefSkipTitle => 'Увімкнути пропускання днів';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Перемкніть двічі, щоб додати пропуск замість галочки. Пропуски зберігають ваш результат незмінним і не переривають серію.';

  @override
  String get prefUnknownTitle => 'Показувати знаки питання для відсутніх даних';

  @override
  String get prefUnknownDescription =>
      'Відрізняти дні без даних від фактичних пропусків. Щоб увести пропуск, перемкніть двічі.';

  @override
  String get youAreNowADeveloper => 'Тепер ви – розробник';

  @override
  String get activityNotFound => 'Не знайдено програми для підтримки цієї дії';

  @override
  String get prefMidnightDelayTitle =>
      'Продовжити день на кілька годин після опівночі';

  @override
  String get prefMidnightDelayDescription =>
      'Почекати до 3:00 перед показом нового дня. Корисно, якщо ви зазвичай лягаєте спати після опівночі. Потрібно перезапустити програму.';

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
      other: 'Звички змінено',
      many: 'Звички змінено',
      few: 'Звички змінено',
      one: 'Звичку змінено',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Звички вилучено',
      many: 'Звички вилучено',
      few: 'Звички вилучено',
      one: 'Звичку вилучено',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Звички архівовано',
      many: 'Звички архівовано',
      few: 'Звички архівовано',
      one: 'Звичку архівовано',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Звички розархівовано',
      many: 'Звички розархівовано',
      few: 'Звички розархівовано',
      one: 'Звичку розархівовано',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Вилучити звички?',
      many: 'Вилучити звички?',
      few: 'Вилучити звички?',
      one: 'Вилучити звичку?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Звички вилучаться назавжди. Цю дію неможливо скасувати.',
      many: 'Звички вилучаться назавжди. Цю дію неможливо скасувати.',
      few: 'Звички вилучаться назавжди. Цю дію неможливо скасувати.',
      one: 'Звичка вилучиться назавжди. Цю дію неможливо скасувати.',
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
  String get sleepQuestionExample => 'e.g. How did you sleep last night?';

  @override
  String get sleepSkipThisDay => 'Skip this day';

  @override
  String get sleepSkipExplained =>
      'Recorded, but not counted for or against you.';

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

  @override
  String get abstinenceHabitType => 'Abstinence';

  @override
  String get abstinenceHabitTypeExample =>
      'e.g. No alcohol. No doomscrolling. Silence is a clean day — you only mark the days you slipped.';

  @override
  String get abstinenceQuestionExample => 'e.g. Did you slip today?';

  @override
  String get abstinenceAllowance => 'Allowance';

  @override
  String get abstinenceAllowanceExample => 'e.g. 30';

  @override
  String get abstinenceAllowanceUnit => 'Counted in';

  @override
  String get abstinenceAllowanceUnitExample => 'e.g. minutes';

  @override
  String get abstinenceCommittedFrom => 'Committed since';

  @override
  String get abstinenceTitle => 'Without a lapse';

  @override
  String abstinenceCleanDaysLabel(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'days without a lapse',
      one: 'day without a lapse',
    );
    return '$_temp0';
  }

  @override
  String abstinenceSince(String date) {
    return 'Since $date';
  }

  @override
  String abstinenceLastLapse(String date) {
    return 'Last lapse: $date';
  }

  @override
  String get abstinenceLapseToday => 'I lapsed today';

  @override
  String get abstinenceUndoToday => 'Undo today';
}
