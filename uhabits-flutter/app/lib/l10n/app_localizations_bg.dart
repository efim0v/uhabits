// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class L10nBg extends L10n {
  L10nBg([String locale = 'bg']) : super(locale);

  @override
  String get overview => 'Обобщение';

  @override
  String get appName => 'Loop Следене на навици';

  @override
  String get mainActivityTitle => 'Навици';

  @override
  String get actionSettings => 'Настройки';

  @override
  String get edit => 'Редактиране';

  @override
  String get delete => 'Изтриване';

  @override
  String get archive => 'Архивиране';

  @override
  String get unarchive => 'Разархивиране';

  @override
  String get addHabit => 'Добавяне на навик';

  @override
  String get colorPickerDefaultTitle => 'Промяна на цвят';

  @override
  String get toastHabitCreated => 'Навикът е създаден';

  @override
  String get habitStrength => 'Сила на навика';

  @override
  String get history => 'История';

  @override
  String get clear => 'Изчистване';

  @override
  String get reminder => 'Напомняне';

  @override
  String get save => 'Запазване';

  @override
  String get streaks => 'Поредици';

  @override
  String get noHabitsFound => 'Нямате активни навици';

  @override
  String get noHabitsLeftToDo => 'Всичко сте изпълнили за днес!';

  @override
  String get longPressToToggle =>
      'Натиснете и задръжте за да добавите или премахнете отметка';

  @override
  String get reminderOff => 'Изключено';

  @override
  String get createHabit => 'Създаване на навик';

  @override
  String get editHabit => 'Редактиране на навик';

  @override
  String get check => 'Поставяне на отметка';

  @override
  String get snooze => 'По-късно';

  @override
  String get introTitle1 => 'Добре дошли';

  @override
  String get introDescription1 =>
      'Loop Следене на навици ви помага да създавате и поддържате добри навици.';

  @override
  String get introTitle2 => 'Създайте нови навици';

  @override
  String get introDescription2 =>
      'Всеки ден, след изпълнението на навика, поставете отметка в приложението.';

  @override
  String get introTitle4 => 'Следете напредъка си';

  @override
  String get introDescription4 =>
      'Подробни диаграми ви показват как вашите навици са се подобрили с времето.';

  @override
  String get interval15Minutes => '15 минути';

  @override
  String get interval30Minutes => '30 минути';

  @override
  String get interval1Hour => '1 час';

  @override
  String get interval2Hour => '2 часа';

  @override
  String get interval4Hour => '4 часа';

  @override
  String get interval8Hour => '8 часа';

  @override
  String get interval24Hour => '24 часа';

  @override
  String get intervalAlwaysAsk => 'Винаги да се пита';

  @override
  String get intervalCustom => 'Персонализирано...';

  @override
  String get prefToggleTitle => 'Маркиране с кратко натискане';

  @override
  String get prefToggleDescription2 =>
      'Поставяне на отметки с кратко натискане вместо с натискане и задържане';

  @override
  String get prefRateThisApp => 'Оценяване на това приложение в Google Play';

  @override
  String get prefSendFeedback => 'Изпращане на отзиви към разработчика';

  @override
  String get prefViewSourceCode => 'Преглед на програмния код в GitHub';

  @override
  String get links => 'Препратки';

  @override
  String get name => 'Име';

  @override
  String get settings => 'Настройки';

  @override
  String get selectSnoozeDelay => 'Избор на време за отлагане';

  @override
  String get hintTitle => 'Знаете ли че?';

  @override
  String get hintDrag =>
      'За да пренаредите записите, натиснете и задръжте върху името на навика и го придърпайте до правилното място.';

  @override
  String get hintLandscape =>
      'Може да виждате повече дни като обърнете телефона си в хоризонтално положение.';

  @override
  String get habitNotFound => 'Навикът е изтрит / не е намерен';

  @override
  String get weekends => 'Събота и неделя';

  @override
  String get anyWeekday => 'От понеделник до петък';

  @override
  String get anyDay => 'Всеки ден от седмицата';

  @override
  String get selectWeekdays => 'Избор на дни';

  @override
  String get exportToCsv => 'Експортиране като CSV';

  @override
  String get doneLabel => 'Готово';

  @override
  String get clearLabel => 'Изчистване';

  @override
  String get selectHours => 'Избиране на час';

  @override
  String get selectMinutes => 'Избиране на минута';

  @override
  String get about => 'За приложението';

  @override
  String get translators => 'Преводачи';

  @override
  String get developers => 'Разработчици';

  @override
  String versionN(String p1) {
    return 'Версия $p1';
  }

  @override
  String get frequency => 'Честота';

  @override
  String get checkmark => 'Отметка';

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
  String get bestStreaks => 'Най-добри поредици';

  @override
  String get everyDay => 'Всеки ден';

  @override
  String get everyWeek => 'Всяка седмица';

  @override
  String get help => 'Помощ & ЧЗВ';

  @override
  String get couldNotExport => 'Неуспешно експортиране на данни.';

  @override
  String get couldNotImport => 'Неуспешно импортиране на данни.';

  @override
  String get fileNotRecognized => 'Файлът не е разпознат.';

  @override
  String get habitsImported => 'Навиците са импортирани успешно.';

  @override
  String get importData => 'Импортиране на данни';

  @override
  String get exportFullBackup => 'Експортиране на пълно резервно копие';

  @override
  String get importDataSummary =>
      'Поддържа пълни резервни копия експортирани чрез това приложение, както и файлове генерирани чрез Tickmate, HabitBull или Rewire. Вижте ЧЗВ за повече информация.';

  @override
  String get exportAsCsvSummary =>
      'Генерира файлове, които могат да се отварят със софтуер за електронни таблици като Microsoft Excel или OpenOffice Calc. Този файл не може да се импортира обратно.';

  @override
  String get exportFullBackupSummary =>
      'Генерира файл, който съдържа всичките ви данни. Този файл може да бъде импортиран обратно.';

  @override
  String get selectPublicBackupFolder =>
      'Изберете публична папка за резервни копия';

  @override
  String get noPublicBackupFolderSelected => 'Не е избрана папка';

  @override
  String get bugReportFailed => 'Неуспешно генериране на доклад за грешки.';

  @override
  String get generateBugReport => 'Генериране на доклад за грешки';

  @override
  String get troubleshooting => 'Отстраняване на проблеми';

  @override
  String get helpTranslate => 'Помагане за превода на това приложение';

  @override
  String get nightMode => 'Тъмна тема';

  @override
  String get usePureBlack => 'Използване на чисто черно при тъмна тема';

  @override
  String get pureBlackDescription =>
      'Заменя сивите фонове с чисто черни при тъмна тема. Намаля разхода на батерията при телефони с AMOLED дисплеи.';

  @override
  String get interfacePreferences => 'Интерфейс';

  @override
  String get reverseDays => 'Обратен ред на дните';

  @override
  String get reverseDaysDescription =>
      'Показва дните на основния екран в обратен ред';

  @override
  String get day => 'Ден';

  @override
  String get week => 'Седмица';

  @override
  String get month => 'Месец';

  @override
  String get quarter => 'Тримесечие';

  @override
  String get year => 'Година';

  @override
  String get total => 'Общо';

  @override
  String get yesOrNo => 'Да или не';

  @override
  String everyXDays(int p1) {
    return 'На всеки $p1 дни';
  }

  @override
  String everyXWeeks(int p1) {
    return 'На всеки $p1 седмици';
  }

  @override
  String get score => 'Сила';

  @override
  String get reminderSound => 'Звук за напомняне';

  @override
  String get none => 'Няма';

  @override
  String get filter => 'Филтър';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Скриване на завършените';

  @override
  String get hideEntered => 'Скриване на въведените';

  @override
  String get hideArchived => 'Скриване на архивираните';

  @override
  String get stickyNotifications => 'Направи известията постоянни';

  @override
  String get stickyNotificationsDescription =>
      'Предотвратява изчистването на известията с плъзване настрани.';

  @override
  String get ledNotifications => 'Светлина за известяване';

  @override
  String get ledNotificationsDescription =>
      'Показва мигаща светлина за напомняния. Налична само за телефони с LED светлини за известяване.';

  @override
  String get repairDatabase => 'Поправка на базата данни';

  @override
  String get databaseRepaired => 'Базата данни е поправена.';

  @override
  String get uncheck => 'Премахване на отметка';

  @override
  String get toggle => 'Смяна';

  @override
  String get action => 'Действие';

  @override
  String get habit => 'Навик';

  @override
  String get sort => 'Сортиране';

  @override
  String get manually => 'Ръчно';

  @override
  String get byName => 'По име';

  @override
  String get byColor => 'По цвят';

  @override
  String get byScore => 'По сила';

  @override
  String get byStatus => 'По състояние';

  @override
  String get export => 'Експортиране';

  @override
  String get longPressToEdit =>
      'Натиснете и задръжте за да промените стойността';

  @override
  String get value => 'Стойност';

  @override
  String get calendar => 'Календар';

  @override
  String get unit => 'Мерна единица';

  @override
  String get targetType => 'Тип на целта';

  @override
  String get targetTypeAtLeast => 'Най-малко';

  @override
  String get targetTypeAtMost => 'Най-много';

  @override
  String get exampleQuestionBoolean => 'напр. Тренирахте ли днес?';

  @override
  String get question => 'Въпрос';

  @override
  String get target => 'Цел';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Не';

  @override
  String get customizeNotificationSummary =>
      'Промяна на звук, вибрация, светлина и други настройки на известията';

  @override
  String get customizeNotification => 'Персонализиране на известията';

  @override
  String get prefViewPrivacy => 'Преглед на политиката за поверителност';

  @override
  String get viewAllContributors => 'Преглед на всички сътрудници...';

  @override
  String get database => 'База данни';

  @override
  String get widgetOpacityTitle => 'Прозрачност на приспособлението';

  @override
  String get widgetOpacityDescription =>
      'Прави приспособленията по-прозрачни или по-непрозрачни на началния ви екран';

  @override
  String get firstDayOfTheWeek => 'Първи ден от седмицата';

  @override
  String get defaultReminderQuestion => 'Изпълнихте ли навика днес?';

  @override
  String get notes => 'Бележки';

  @override
  String get exampleNotes => '(Незадължително)';

  @override
  String get yesOrNoExample =>
      'напр. Събудихте ли се рано днес? Тренирахте ли? Играхте ли шах?';

  @override
  String get measurable => 'Измерим';

  @override
  String get measurableExample =>
      'напр. Колко километра пробягахте днес? Колко страници прочетохте?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 пъти седмично';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 пъти месечно';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 пъти в период от $p2 дни';
  }

  @override
  String get yesOrNoShortExample => 'напр. Тренировка';

  @override
  String get color => 'Цвят';

  @override
  String get exampleTarget => 'напр. 15';

  @override
  String get measurableShortExample => 'напр. Бягане';

  @override
  String get measurableQuestionExample =>
      'напр. Колко километра пробягахте днес?';

  @override
  String get measurableUnitsExample => 'напр. км';

  @override
  String get everyMonth => 'Всеки месец';

  @override
  String get validationCannotBeBlank => 'Не може да бъде празно';

  @override
  String get today => 'Днес';

  @override
  String get enter => 'Въвеждане';

  @override
  String get noHabits => 'Не са намерени навици';

  @override
  String get noNumericalHabits => 'Не са намерени измерими навици';

  @override
  String get noBooleanHabits => 'Не са намерени навици от тип \"да или не\"';

  @override
  String get increment => 'Увеличаване';

  @override
  String get decrement => 'Намаляване';

  @override
  String get prefSkipTitle => 'Включване на пропуснати дни';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Маркирайте два пъти за да добавите пропускане вместо отметка. Пропусканията поддържат силата на навика ви непроменена и не прекъсват поредицата ви.';

  @override
  String get prefUnknownTitle => 'Показване на питанки при липсващи данни';

  @override
  String get prefUnknownDescription =>
      'Разграничаване на дните без данни от реални пропуски. За да добавите пропуск, маркирайте два пъти.';

  @override
  String get youAreNowADeveloper => 'Вие вече сте разработчик';

  @override
  String get activityNotFound =>
      'Не е намерено приложение, което да поддържа това действие';

  @override
  String get prefMidnightDelayTitle =>
      'Удължаване на деня с няколко часа след полунощ';

  @override
  String get prefMidnightDelayDescription =>
      'Изчакване до 3:00 часа сутринта за показване на нов ден. Полезно, ако обичайно си лягате да спите след полунощ. Изисква рестартиране на приложението.';

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
      other: 'Навиците са променени',
      one: 'Навикът е променен',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навиците са изтрити',
      one: 'Навикът е изтрит',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навиците са архивирани',
      one: 'Навикът е архивиран',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навиците са разархивирани',
      one: 'Навикът е разархивиран',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Изтриване на навици?',
      one: 'Изтриване на навик?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Навиците ще бъдат перманентно изтрити. Това действие не може да бъде отменено.',
      one:
          'Навикът ще бъде перманентно изтрит. Това действие не може да бъде отменено.',
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

  @override
  String abstinenceAmountPrompt(String allowance, String unit) {
    return 'No more than $allowance $unit a day';
  }

  @override
  String abstinenceAmountPromptNoUnit(String allowance) {
    return 'No more than $allowance a day';
  }
}
