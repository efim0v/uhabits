// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class L10nSr extends L10n {
  L10nSr([String locale = 'sr']) : super(locale);

  @override
  String get overview => 'Преглед';

  @override
  String get appName => '„Loop“ — праћење навика';

  @override
  String get mainActivityTitle => 'Навике';

  @override
  String get actionSettings => 'Поставке';

  @override
  String get edit => 'Уређивање';

  @override
  String get delete => 'Обриши';

  @override
  String get archive => 'Архивирај';

  @override
  String get unarchive => 'Врати из архива';

  @override
  String get addHabit => 'Нова навика';

  @override
  String get colorPickerDefaultTitle => 'Измени боју';

  @override
  String get toastHabitCreated => 'Навика направљена';

  @override
  String get habitStrength => 'Моћ навике';

  @override
  String get history => 'Историја';

  @override
  String get clear => 'Очисти';

  @override
  String get reminder => 'Подсетник';

  @override
  String get save => 'Сачувај';

  @override
  String get streaks => 'Рекорди';

  @override
  String get noHabitsFound => 'Немате активних навика';

  @override
  String get noHabitsLeftToDo => 'Завршили сте за данас!';

  @override
  String get longPressToToggle => 'Дуг притисак за мењање стања';

  @override
  String get reminderOff => 'искључен';

  @override
  String get createHabit => 'Стварање навике';

  @override
  String get editHabit => 'Уређивање навике';

  @override
  String get check => 'Потврди';

  @override
  String get snooze => 'Касније';

  @override
  String get introTitle1 => 'Добро дошли';

  @override
  String get introDescription1 =>
      '„Loop“ вам помаже да створите и одржите здраве навике.';

  @override
  String get introTitle2 => 'Створите нове навике';

  @override
  String get introDescription2 =>
      'Сваког дана, након што обавите зацртано, откачите поље у апликацији.';

  @override
  String get introTitle4 => 'Пратите свој напредак';

  @override
  String get introDescription4 =>
      'Детаљни графикони ће вам показати како су се ваше навике временом побољшале.';

  @override
  String get interval15Minutes => '15 минута';

  @override
  String get interval30Minutes => '30 минута';

  @override
  String get interval1Hour => '1 сат';

  @override
  String get interval2Hour => '2 сата';

  @override
  String get interval4Hour => '4 сата';

  @override
  String get interval8Hour => '8 сати';

  @override
  String get interval24Hour => '24 сата';

  @override
  String get intervalAlwaysAsk => 'Увек питај';

  @override
  String get intervalCustom => 'Прилагођено...';

  @override
  String get prefToggleTitle => 'Мењај стање додиром';

  @override
  String get prefToggleDescription2 =>
      'Ставите квачице једним додиром уместо притискањем и држањем.';

  @override
  String get prefRateThisApp => 'Оцени апликацију';

  @override
  String get prefSendFeedback => 'Повратне информације';

  @override
  String get prefViewSourceCode => 'Изворни кôд на Гитхабу';

  @override
  String get links => 'Везе';

  @override
  String get name => 'Назив';

  @override
  String get settings => 'Поставке';

  @override
  String get selectSnoozeDelay => 'Изаберите време одлагања';

  @override
  String get hintTitle => 'Да ли сте знали?';

  @override
  String get hintDrag =>
      'Притисните и држите назив навике па је превуците да бисте их преуредили.';

  @override
  String get hintLandscape => 'У положеном режиму можете видети више дана.';

  @override
  String get habitNotFound => 'Навика обрисана / не постоји';

  @override
  String get weekends => 'викендом';

  @override
  String get anyWeekday => 'радним данима';

  @override
  String get anyDay => 'сваког дана';

  @override
  String get selectWeekdays => 'Избор дана';

  @override
  String get exportToCsv => 'Извези као CSV';

  @override
  String get doneLabel => 'Завршено';

  @override
  String get clearLabel => 'Обриши';

  @override
  String get selectHours => 'Избор часова';

  @override
  String get selectMinutes => 'Избор минута';

  @override
  String get about => 'О програму';

  @override
  String get translators => 'Преводиоци';

  @override
  String get developers => 'Програмери';

  @override
  String versionN(String p1) {
    return 'верзија $p1';
  }

  @override
  String get frequency => 'Учесталост';

  @override
  String get checkmark => 'Квачица';

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
  String get bestStreaks => 'Најбољи низови';

  @override
  String get everyDay => 'сваког дана';

  @override
  String get everyWeek => 'сваке недеље';

  @override
  String get help => 'Помоћ и ЧПП';

  @override
  String get couldNotExport => 'Не могу да извезем податке.';

  @override
  String get couldNotImport => 'Не могу да увезем податке.';

  @override
  String get fileNotRecognized => 'Фајл није препознат.';

  @override
  String get habitsImported => 'Навике су успешно увезене.';

  @override
  String get importData => 'Увези податке';

  @override
  String get exportFullBackup => 'Направи резервну копију';

  @override
  String get importDataSummary =>
      'Поред сопственог формата, програм подржава и увоз фајлова направљених у „Tickmate“, „HabitBull“ и „Rewire“. Детаљније у ЧПП.';

  @override
  String get exportAsCsvSummary =>
      'Прави фајл који можете отворити у програму за рад са табелама (нпр. Мајкрософт Ексел или Опенофис Калк). Не може се увести назад у апликацију.';

  @override
  String get exportFullBackupSummary =>
      'Прави фајл са свим подацима. Може се касније увозити.';

  @override
  String get selectPublicBackupFolder =>
      'Изаберите јавну фасциклу за резервну копију';

  @override
  String get noPublicBackupFolderSelected => 'Ниједна фасцикла није изабрана';

  @override
  String get bugReportFailed => 'Не могу да направим извештај о грешци.';

  @override
  String get generateBugReport => 'Направи извештај о грешци';

  @override
  String get troubleshooting => 'Решавање проблема';

  @override
  String get helpTranslate => 'Помозите превођење';

  @override
  String get nightMode => 'Тамна тема';

  @override
  String get usePureBlack => 'Чиста црна у тамној теми';

  @override
  String get pureBlackDescription =>
      'Мења сиву позадину са чистом црном у тамној теми. Смањује потрошњу батерије код телефона са АМОЛЕД екраном.';

  @override
  String get interfacePreferences => 'Сучеље';

  @override
  String get reverseDays => 'Обрни редослед дана';

  @override
  String get reverseDaysDescription =>
      'Приказ дана у обрнутом реду на главном екрану.';

  @override
  String get day => 'дан';

  @override
  String get week => 'недеља';

  @override
  String get month => 'месец';

  @override
  String get quarter => 'тромесечје';

  @override
  String get year => 'година';

  @override
  String get total => 'укупно';

  @override
  String get yesOrNo => 'Да или не';

  @override
  String everyXDays(int p1) {
    return 'Сваких $p1 дана';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Свакe $p1 недељe';
  }

  @override
  String get score => 'снага';

  @override
  String get reminderSound => 'Звук подсетника';

  @override
  String get none => 'без звука';

  @override
  String get filter => 'Филтер';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Сакриј завршено';

  @override
  String get hideEntered => 'Сакриј унесене';

  @override
  String get hideArchived => 'Сакриј архивирано';

  @override
  String get stickyNotifications => 'Учини обавештења трајним';

  @override
  String get stickyNotificationsDescription => 'Спречава уклањање обавештења.';

  @override
  String get ledNotifications => 'Светло обавештења';

  @override
  String get ledNotificationsDescription =>
      'Приказује трепћуће светло као подсетник. Само на телефонима са ЛЕД светлом за обавештавање.';

  @override
  String get repairDatabase => 'Поправи базу података';

  @override
  String get databaseRepaired => 'База података поправљена';

  @override
  String get uncheck => 'Опозови';

  @override
  String get toggle => 'Обрни';

  @override
  String get action => 'Радња';

  @override
  String get habit => 'Навика';

  @override
  String get sort => 'Разврстај';

  @override
  String get manually => 'ручно';

  @override
  String get byName => 'по називу';

  @override
  String get byColor => 'по боји';

  @override
  String get byScore => 'по резултату';

  @override
  String get byStatus => 'по стању';

  @override
  String get export => 'Извоз';

  @override
  String get longPressToEdit => 'Дуг притисак за промену вредности';

  @override
  String get value => 'Вредност';

  @override
  String get calendar => 'Календар';

  @override
  String get unit => 'Јединица';

  @override
  String get targetType => 'Врста циља';

  @override
  String get targetTypeAtLeast => 'најмање';

  @override
  String get targetTypeAtMost => 'највише';

  @override
  String get exampleQuestionBoolean => 'нпр. Да ли сте вежбали данас?';

  @override
  String get question => 'Питање';

  @override
  String get target => 'Циљ';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Не';

  @override
  String get customizeNotificationSummary =>
      'Мењајте звук, вибрацију, светло и друге поставке обавештавања';

  @override
  String get customizeNotification => 'Прилагодите обавештења';

  @override
  String get prefViewPrivacy => 'Приказ политике приватности';

  @override
  String get viewAllContributors => 'прикажи све сараднике…';

  @override
  String get database => 'База података';

  @override
  String get widgetOpacityTitle => 'Прозирност виџета';

  @override
  String get widgetOpacityDescription =>
      'Мења прозирност виџета на почетном екрану.';

  @override
  String get firstDayOfTheWeek => 'Први дан у недељи';

  @override
  String get defaultReminderQuestion => 'Да ли сте данас ово обавили?';

  @override
  String get notes => 'Напомене';

  @override
  String get exampleNotes => 'није обавезно';

  @override
  String get yesOrNoExample =>
      'нпр. Да ли сте данас рано устали? Да ли сте вежбали? Јесте ли играли шах?';

  @override
  String get measurable => 'Мерљиво';

  @override
  String get measurableExample =>
      'нпр. Колико сте километара претрчали данас? Колико сте страница прочитали?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 пута недељно';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 пута месечно';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 пута у $p2 дана';
  }

  @override
  String get yesOrNoShortExample => 'нпр. вежбање';

  @override
  String get color => 'Боја';

  @override
  String get exampleTarget => 'нпр. 15';

  @override
  String get measurableShortExample => 'нпр. трчање';

  @override
  String get measurableQuestionExample => 'нпр. Колико сте данас претрчали?';

  @override
  String get measurableUnitsExample => 'нпр. km';

  @override
  String get everyMonth => 'сваког месеца';

  @override
  String get validationCannotBeBlank => 'не може бити празно';

  @override
  String get today => 'Данас';

  @override
  String get enter => 'Унос';

  @override
  String get noHabits => 'Нема навика';

  @override
  String get noNumericalHabits => 'Нема мерљивих навика';

  @override
  String get noBooleanHabits => 'Нема да/не навика';

  @override
  String get increment => 'повећање';

  @override
  String get decrement => 'умањење';

  @override
  String get prefSkipTitle => 'Омогући прескакање дана';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Двапут промените да бисте прескочили уместо откачињања. Прескакање задржава резултат непромењеним и не прекида низ.';

  @override
  String get prefUnknownTitle => 'Приказ упитника где нема података';

  @override
  String get prefUnknownDescription =>
      'Разликује дане без података са стварним пропуштањем. За прескок, потврдите два пута.';

  @override
  String get youAreNowADeveloper => 'Постали сте програмер';

  @override
  String get activityNotFound => 'Нема апликације која подржава ову радњу';

  @override
  String get prefMidnightDelayTitle => 'Продужите дан неколико сати иза поноћи';

  @override
  String get prefMidnightDelayDescription =>
      'Чека до 03:00 да покаже нови дан. Корисно ако обично идете на спавање после поноћи. Захтева поновно покретање.';

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
      other: 'Навикe измењенe',
      few: 'Навикe измењенe',
      one: 'Навика измењена',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навике обрисане',
      few: 'Навике обрисане',
      one: 'Навика обрисана',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навике архивиране',
      few: 'Навике архивиране',
      one: 'Навика архивирана',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навике враћене из архиве',
      few: 'Навике враћене из архиве',
      one: 'Навика враћена из архиве',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Обрисати навике?',
      few: 'Обрисати навике?',
      one: 'Обрисати навикe?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Навике ће бити трајно обрисане. Ова радња је неповратна.',
      few: 'Навике ће бити трајно обрисане. Ова радња је неповратна.',
      one: 'Навике ће бити трајно обрисане. Ова радња је неповратна.',
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

  @override
  String abstinenceDurationYears(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '$count year',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMonths(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '$count month',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String abstinenceDurationMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get abstinenceOfRecord => 'of the record';

  @override
  String get abstinenceOfPrevious => 'of the previous run';

  @override
  String get abstinenceIsRecord => 'record';

  @override
  String get abstinenceLapsesTotal => 'lapses';
}

/// The translations for Serbian, using the Latin script (`sr_Latn`).
class L10nSrLatn extends L10nSr {
  L10nSrLatn() : super('sr_Latn');

  @override
  String get overview => 'Pregled';

  @override
  String get appName => '„Loop“ — praćenje navika';

  @override
  String get mainActivityTitle => 'Navike';

  @override
  String get actionSettings => 'Postavke';

  @override
  String get edit => 'Uređivanje';

  @override
  String get delete => 'Obriši';

  @override
  String get archive => 'Arhiviraj';

  @override
  String get unarchive => 'Dearhiviraj';

  @override
  String get addHabit => 'Nova navika';

  @override
  String get colorPickerDefaultTitle => 'Izmeni boju';

  @override
  String get toastHabitCreated => 'Navika napravljena';

  @override
  String get habitStrength => 'Moć navike';

  @override
  String get history => 'Istorija';

  @override
  String get clear => 'Očisti';

  @override
  String get reminder => 'Podsetnik';

  @override
  String get save => 'Sačuvaj';

  @override
  String get streaks => 'Rekordi';

  @override
  String get noHabitsFound => 'Nemate aktivnih navika';

  @override
  String get noHabitsLeftToDo => 'Završili ste za danas!';

  @override
  String get longPressToToggle => 'Dug pritisak za menjanje stanja';

  @override
  String get reminderOff => 'isključen';

  @override
  String get createHabit => 'Stvaranje navike';

  @override
  String get editHabit => 'Uređivanje navike';

  @override
  String get check => 'Potvrdi';

  @override
  String get snooze => 'Kasnije';

  @override
  String get introTitle1 => 'Dobro došli';

  @override
  String get introDescription1 =>
      '„Loop“ vam pomaže da stvorite i održite zdrave navike.';

  @override
  String get introTitle2 => 'Stvorite nove navike';

  @override
  String get introDescription2 =>
      'Svakog dana, nakon što obavite zacrtano, otkačite polje u aplikaciji.';

  @override
  String get introTitle4 => 'Pratite svoj napredak';

  @override
  String get introDescription4 =>
      'Detaljni grafikoni će vam pokazati kako su se vaše navike vremenom poboljšale.';

  @override
  String get interval15Minutes => '15 minuta';

  @override
  String get interval30Minutes => '30 minuta';

  @override
  String get interval1Hour => '1 sat';

  @override
  String get interval2Hour => '2 sata';

  @override
  String get interval4Hour => '4 sata';

  @override
  String get interval8Hour => '8 sati';

  @override
  String get interval24Hour => '24 sata';

  @override
  String get intervalAlwaysAsk => 'Uvek pitaj';

  @override
  String get intervalCustom => 'Prilagođeno...';

  @override
  String get prefToggleTitle => 'Menjaj stanje dodirom';

  @override
  String get prefRateThisApp => 'Oceni aplikaciju';

  @override
  String get prefSendFeedback => 'Povratne informacije';

  @override
  String get prefViewSourceCode => 'Izvorni kôd na Githabu';

  @override
  String get links => 'Veze';

  @override
  String get name => 'Naziv';

  @override
  String get settings => 'Postavke';

  @override
  String get selectSnoozeDelay => 'Izaberite vreme odlaganja';

  @override
  String get hintTitle => 'Da li ste znali?';

  @override
  String get hintDrag =>
      'Pritisnite i držite naziv navike pa je prevucite da biste ih preuredili.';

  @override
  String get hintLandscape => 'U položenom režimu možete videti više dana.';

  @override
  String get habitNotFound => 'Navika obrisana / ne postoji';

  @override
  String get weekends => 'vikendom';

  @override
  String get anyWeekday => 'radnim danima';

  @override
  String get anyDay => 'svakog dana';

  @override
  String get selectWeekdays => 'Izbor dana';

  @override
  String get exportToCsv => 'Izvezi kao CSV';

  @override
  String get doneLabel => 'Završeno';

  @override
  String get clearLabel => 'Očisti';

  @override
  String get selectHours => 'Izbor časova';

  @override
  String get selectMinutes => 'Izbor minuta';

  @override
  String get about => 'O programu';

  @override
  String get translators => 'Prevodioci';

  @override
  String get developers => 'Programeri';

  @override
  String versionN(String p1) {
    return 'verzija $p1';
  }

  @override
  String get frequency => 'Učestalost';

  @override
  String get checkmark => 'Kvačica';

  @override
  String get bestStreaks => 'Najbolji nizovi';

  @override
  String get everyDay => 'svakog dana';

  @override
  String get everyWeek => 'svake nedelje';

  @override
  String get help => 'Pomoć i ČPP';

  @override
  String get couldNotExport => 'Ne mogu da izvezem podatke.';

  @override
  String get couldNotImport => 'Ne mogu da uvezem podatke.';

  @override
  String get fileNotRecognized => 'Fajl nije prepoznat.';

  @override
  String get habitsImported => 'Navike su uspešno uvezene.';

  @override
  String get importData => 'Uvezi podatke';

  @override
  String get exportFullBackup => 'Napravi rezervnu kopiju';

  @override
  String get importDataSummary =>
      'Pored sopstvenog formata, program podržava i uvoz fajlova napravljenih u „Tickmate“, „HabitBull“ i „Rewire“. Detaljnije u ČPP.';

  @override
  String get exportAsCsvSummary =>
      'Pravi fajl koji možete otvoriti u programu za rad sa tabelama (npr. Microsoft Excel ili OpenOffice Calc). Ne može se uvesti nazad u aplikaciju.';

  @override
  String get exportFullBackupSummary =>
      'Pravi fajl sa svim podacima. Može se kasnije uvoziti.';

  @override
  String get selectPublicBackupFolder =>
      'Izaberite javni folder za rezervnu kopiju';

  @override
  String get noPublicBackupFolderSelected => 'Nijedan folder nije izabran';

  @override
  String get bugReportFailed => 'Ne mogu da napravim izveštaj o grešci.';

  @override
  String get generateBugReport => 'Napravi izveštaj o grešci';

  @override
  String get troubleshooting => 'Rešavanje problema';

  @override
  String get helpTranslate => 'Pomozite prevođenje';

  @override
  String get nightMode => 'Tamna tema';

  @override
  String get usePureBlack => 'Čista crna u tamnoj temi';

  @override
  String get pureBlackDescription =>
      'Menja sivu pozadinu sa čistom crnom u tamnoj temi. Smanjuje potrošnju baterije kod telefona sa AMOLED ekranom.';

  @override
  String get interfacePreferences => 'Sučelje';

  @override
  String get reverseDays => 'Obrni redosled dana';

  @override
  String get reverseDaysDescription =>
      'Prikaz dana u obrnutom redu na glavnom ekranu.';

  @override
  String get day => 'dan';

  @override
  String get week => 'nedelja';

  @override
  String get month => 'mesec';

  @override
  String get quarter => 'tromesečje';

  @override
  String get year => 'godina';

  @override
  String get total => 'ukupno';

  @override
  String get yesOrNo => 'Da ili ne';

  @override
  String everyXDays(int p1) {
    return 'Svakih $p1 dana';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Svake $p1 nedelje';
  }

  @override
  String get score => 'snaga';

  @override
  String get reminderSound => 'Zvuk podsetnika';

  @override
  String get none => 'bez zvuka';

  @override
  String get filter => 'Filter';

  @override
  String get hideCompleted => 'Sakrij završeno';

  @override
  String get hideArchived => 'Sakrij arhivirano';

  @override
  String get stickyNotifications => 'Učini obaveštenja trajnim';

  @override
  String get stickyNotificationsDescription =>
      'Sprečava uklanjanje obaveštenja.';

  @override
  String get ledNotifications => 'Svetlo obaveštenja';

  @override
  String get ledNotificationsDescription =>
      'Prikazuje trepćuće svetlo kao podsetnik. Samo na telefonima sa LED svetlom za obaveštavanje.';

  @override
  String get repairDatabase => 'Popravi bazu podataka';

  @override
  String get databaseRepaired => 'Baza podataka popravljena';

  @override
  String get uncheck => 'Opozovi';

  @override
  String get toggle => 'Obrni';

  @override
  String get action => 'Radnja';

  @override
  String get habit => 'Navika';

  @override
  String get sort => 'Razvrstaj';

  @override
  String get manually => 'ručno';

  @override
  String get byName => 'po nazivu';

  @override
  String get byColor => 'po boji';

  @override
  String get byScore => 'po rezultatu';

  @override
  String get byStatus => 'po stanju';

  @override
  String get export => 'Izvoz';

  @override
  String get longPressToEdit => 'Dug pritisak za promenu vrednosti';

  @override
  String get calendar => 'Kalendar';

  @override
  String get unit => 'Jedinica';

  @override
  String get exampleQuestionBoolean => 'npr. Da li ste vežbali danas?';

  @override
  String get question => 'Pitanje';

  @override
  String get target => 'Cilj';

  @override
  String get yes => 'Da';

  @override
  String get no => 'Ne';

  @override
  String get customizeNotificationSummary =>
      'Menjajte zvuk, vibraciju, svetlo i druge postavke obaveštavanja';

  @override
  String get customizeNotification => 'Prilagodite obaveštenja';

  @override
  String get prefViewPrivacy => 'Prikaz politike privatnosti';

  @override
  String get viewAllContributors => 'prikaži sve saradnike…';

  @override
  String get database => 'Baza podataka';

  @override
  String get widgetOpacityTitle => 'Prozirnost vidžeta';

  @override
  String get widgetOpacityDescription =>
      'Menja prozirnost vidžeta na početnom ekranu.';

  @override
  String get firstDayOfTheWeek => 'Prvi dan u nedelji';

  @override
  String get defaultReminderQuestion => 'Da li ste danas ovo obavili?';

  @override
  String get notes => 'Napomene';

  @override
  String get exampleNotes => 'nije obavezno';

  @override
  String get yesOrNoExample =>
      'npr. Da li ste danas rano ustali? Da li ste vežbali? Jeste li igrali šah?';

  @override
  String get measurable => 'Merljivo';

  @override
  String get measurableExample =>
      'npr. Koliko ste kilometara pretrčali danas? Koliko ste stranica pročitali?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 puta nedeljno';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 puta mesečno';
  }

  @override
  String get yesOrNoShortExample => 'npr. vežbanje';

  @override
  String get color => 'Boja';

  @override
  String get exampleTarget => 'npr. 15';

  @override
  String get measurableShortExample => 'npr. trčanje';

  @override
  String get measurableQuestionExample => 'npr. Koliko ste danas pretrčali?';

  @override
  String get measurableUnitsExample => 'npr. km';

  @override
  String get everyMonth => 'svakog meseca';

  @override
  String get validationCannotBeBlank => 'ne može biti prazno';

  @override
  String get today => 'Danas';

  @override
  String get enter => 'Ulaz';

  @override
  String get noHabits => 'Nema navika';

  @override
  String get noNumericalHabits => 'Nema merljivih navika';

  @override
  String get noBooleanHabits => 'Nema da/ne navika';

  @override
  String get increment => 'povećanje';

  @override
  String get decrement => 'umanjenje';

  @override
  String get prefSkipTitle => 'Omogući preskakanje dana';

  @override
  String get prefSkipDescription =>
      'Dvaput promenite da biste preskočili umesto otkačinjanja. Preskakanje zadržava rezultat nepromenjenim i ne prekida niz.';

  @override
  String get prefUnknownTitle => 'Prikaz upitnika gde nema podataka';

  @override
  String get prefUnknownDescription =>
      'Razlikuje dane bez podataka sa stvarnim propuštanjem. Za preskok, potvrdite dva puta.';

  @override
  String get youAreNowADeveloper => 'Postali ste programer';

  @override
  String get activityNotFound => 'Nema aplikacije koja podržava ovu radnju';

  @override
  String get prefMidnightDelayTitle => 'Produžite dan nekoliko sati iza ponoći';

  @override
  String get prefMidnightDelayDescription =>
      'Čeka do 03:00 da pokaže novi dan. Korisno ako obično idete na spavanje posle ponoći. Zahteva ponovno pokretanje.';

  @override
  String toastHabitsChanged(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike izmenjene',
      few: 'Navike izmenjene',
      one: 'Navika izmenjena',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike obrisane',
      few: 'Navike obrisane',
      one: 'Navika obrisana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike arhivirane',
      few: 'Navike arhivirane',
      one: 'Navika arhivirana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike dearhivirane',
      few: 'Navike dearhivirane',
      one: 'Navika dearhivirana',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Obrisati navike?',
      few: 'Obrisati navike?',
      one: 'Obrisati navike?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike će biti trajno obrisane. Ova radnja je nepovratna.',
      few: 'Navike će biti trajno obrisane. Ova radnja je nepovratna.',
      one: 'Navike će biti trajno obrisane. Ova radnja je nepovratna.',
    );
    return '$_temp0';
  }
}
