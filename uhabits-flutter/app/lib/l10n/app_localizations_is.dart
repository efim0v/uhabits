// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Icelandic (`is`).
class L10nIs extends L10n {
  L10nIs([String locale = 'is']) : super(locale);

  @override
  String get overview => 'Yfirlit';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Venjur';

  @override
  String get actionSettings => 'Stillingar';

  @override
  String get edit => 'Breyta';

  @override
  String get delete => 'Eyða';

  @override
  String get archive => 'Setja í geymslu';

  @override
  String get unarchive => 'Taka úr geymslu';

  @override
  String get addHabit => 'Ný venja';

  @override
  String get colorPickerDefaultTitle => 'Breyta lit';

  @override
  String get toastHabitCreated => 'Venja sköpuð';

  @override
  String get habitStrength => 'Habit strength';

  @override
  String get history => 'Ferill';

  @override
  String get clear => 'Hreinsa';

  @override
  String get reminder => 'Áminning';

  @override
  String get save => 'Vista';

  @override
  String get streaks => 'Streaks';

  @override
  String get noHabitsFound => 'You have no active habits';

  @override
  String get noHabitsLeftToDo => 'Þú ert búin(n) í dag!';

  @override
  String get longPressToToggle => 'Press-and-hold to check or uncheck';

  @override
  String get reminderOff => 'Af';

  @override
  String get createHabit => 'Búa til venju';

  @override
  String get editHabit => 'Breyta venju';

  @override
  String get check => 'Merkja';

  @override
  String get snooze => 'Seinna';

  @override
  String get introTitle1 => 'Velkomin(n)';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker helps you create and maintain good habits.';

  @override
  String get introTitle2 => 'Create some new habits';

  @override
  String get introDescription2 =>
      'Every day, after performing your habit, put a checkmark on the app.';

  @override
  String get introTitle4 => 'Fylgstu með framförum þínum';

  @override
  String get introDescription4 =>
      'Detailed graphs show you how your habits improved over time.';

  @override
  String get interval15Minutes => '15 mínútur';

  @override
  String get interval30Minutes => '30 mínútur';

  @override
  String get interval1Hour => '1 klukkustund';

  @override
  String get interval2Hour => '2 Klukkustundir';

  @override
  String get interval4Hour => '4 klukkustundir';

  @override
  String get interval8Hour => '8 klukkustundir';

  @override
  String get interval24Hour => 'Sólarhring';

  @override
  String get intervalAlwaysAsk => 'Alltaf spyrja';

  @override
  String get intervalCustom => 'Sérsniðið…';

  @override
  String get prefToggleTitle => 'Toggle with short press';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Gefa forriti einkunn á Google Play';

  @override
  String get prefSendFeedback => 'Senda athugasemdir til höfunda';

  @override
  String get prefViewSourceCode => 'Skoða frumkóðann á GitHub';

  @override
  String get links => 'Tenglar';

  @override
  String get name => 'Heiti';

  @override
  String get settings => 'Stillingar';

  @override
  String get selectSnoozeDelay => 'Stilla töf á blundi';

  @override
  String get hintTitle => 'Vissir þú?';

  @override
  String get hintDrag =>
      'To rearrange the entries, press-and-hold on the name of the habit, then drag it to the correct place.';

  @override
  String get hintLandscape =>
      'You can see more days by putting your phone in landscape mode.';

  @override
  String get habitNotFound => 'Habit deleted / not found';

  @override
  String get weekends => 'Helgar';

  @override
  String get anyWeekday => 'Virka daga';

  @override
  String get anyDay => 'Alla daga';

  @override
  String get selectWeekdays => 'Veldu daga';

  @override
  String get exportToCsv => 'Flytja út sem CSV';

  @override
  String get doneLabel => 'Í lagi';

  @override
  String get clearLabel => 'Hreinsa';

  @override
  String get selectHours => 'Veldu klukkustundir';

  @override
  String get selectMinutes => 'Veldu mínútur';

  @override
  String get about => 'Um';

  @override
  String get translators => 'Þýðendur';

  @override
  String get developers => 'Hönnuðir';

  @override
  String versionN(String p1) {
    return 'Útgáfa $p1';
  }

  @override
  String get frequency => 'Tíðni';

  @override
  String get checkmark => 'Gátmerki';

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
  String get bestStreaks => 'Best streaks';

  @override
  String get everyDay => 'Daglega';

  @override
  String get everyWeek => 'Vikulega';

  @override
  String get help => 'Aðstoð og algengar spurningar';

  @override
  String get couldNotExport => 'Mistókst að flytja gögn út.';

  @override
  String get couldNotImport => 'Mistókst að flytja inn gögn.';

  @override
  String get fileNotRecognized => 'Skrá ekki þekkt.';

  @override
  String get habitsImported => 'Venjur fluttar inn.';

  @override
  String get importData => 'Flytja inn gögn';

  @override
  String get exportFullBackup => 'Flytja út fullt öryggisafrit';

  @override
  String get importDataSummary =>
      'Supports full backups exported by this app, as well as files generated by Tickmate, HabitBull or Rewire. See FAQ for more information.';

  @override
  String get exportAsCsvSummary =>
      'Generates files that can be opened by spreadsheet software such as Microsoft Excel or OpenOffice Calc. This file cannot be imported back.';

  @override
  String get exportFullBackupSummary =>
      'Generates a file that contains all your data. This file can be imported back.';

  @override
  String get selectPublicBackupFolder => 'Veldu opinbera öryggisafritunarmöppu';

  @override
  String get noPublicBackupFolderSelected => 'Engin mappa valin';

  @override
  String get bugReportFailed => 'Mistókst að búa til villuskýrslu.';

  @override
  String get generateBugReport => 'Búa til villuskýrslu';

  @override
  String get troubleshooting => 'Leysa vandamál';

  @override
  String get helpTranslate => 'Hjálpa til við að þýða';

  @override
  String get nightMode => 'Dökkt þema';

  @override
  String get usePureBlack => 'Nota kolsvarta þemu';

  @override
  String get pureBlackDescription =>
      'Replaces gray backgrounds with pure black in dark theme. Reduces battery usage in phones with AMOLED display.';

  @override
  String get interfacePreferences => 'Viðmót';

  @override
  String get reverseDays => 'Reverse order of days';

  @override
  String get reverseDaysDescription =>
      'Show days in reverse order on the main screen.';

  @override
  String get day => 'Dagur';

  @override
  String get week => 'Vika';

  @override
  String get month => 'Mánuður';

  @override
  String get quarter => '3 mánuðir';

  @override
  String get year => 'Ár';

  @override
  String get total => 'Samtals';

  @override
  String get yesOrNo => 'Já eða nei';

  @override
  String everyXDays(int p1) {
    return 'Á $p1 daga fresti';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Á $p1 vikna fresti';
  }

  @override
  String get score => 'Árangur';

  @override
  String get reminderSound => 'Tilkynningarhljóð';

  @override
  String get none => 'Ekkert';

  @override
  String get filter => 'Sía';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Fela lokuð';

  @override
  String get hideEntered => 'Hide entered';

  @override
  String get hideArchived => 'Fela í geymslu';

  @override
  String get stickyNotifications => 'Make notifications sticky';

  @override
  String get stickyNotificationsDescription =>
      'Prevents notifications from being swiped away.';

  @override
  String get ledNotifications => 'Tilkynningaljós';

  @override
  String get ledNotificationsDescription =>
      'Shows a blinking light for reminders. Only available in phones with LED notification lights.';

  @override
  String get repairDatabase => 'Lagfæra gagnagrunn';

  @override
  String get databaseRepaired => 'Gagnagrunnur lagfærður.';

  @override
  String get uncheck => 'Afmerkja';

  @override
  String get toggle => 'Víxla';

  @override
  String get action => 'Aðgerð';

  @override
  String get habit => 'Venja';

  @override
  String get sort => 'Raða';

  @override
  String get manually => 'Handvirkt';

  @override
  String get byName => 'Eftir heiti';

  @override
  String get byColor => 'Eftir lit';

  @override
  String get byScore => 'Eftir árangri';

  @override
  String get byStatus => 'Eftir stöðu';

  @override
  String get export => 'Flytja út';

  @override
  String get longPressToEdit => 'Haltu inni til að breyta gildi';

  @override
  String get value => 'Gildi';

  @override
  String get calendar => 'Dagatal';

  @override
  String get unit => 'Mælieining';

  @override
  String get targetType => 'Tegund markmiðs';

  @override
  String get targetTypeAtLeast => 'Að minnsta kosti';

  @override
  String get targetTypeAtMost => 'Í mesta lagi';

  @override
  String get exampleQuestionBoolean => 't.d., Æfðir þú þig í dag?';

  @override
  String get question => 'Spurning';

  @override
  String get target => 'Markmið';

  @override
  String get yes => 'Já';

  @override
  String get no => 'Nei';

  @override
  String get customizeNotificationSummary =>
      'Breyta hljóði, titringi, ljósi og öðrum tilkynningastillingum';

  @override
  String get customizeNotification => 'Sérsníða tilkynningar';

  @override
  String get prefViewPrivacy => 'Skoða persónuverndarstefnu';

  @override
  String get viewAllContributors => 'Skoða alla þátttakendur…';

  @override
  String get database => 'Gagnagrunnur';

  @override
  String get widgetOpacityTitle => 'Ógegnsæi græju';

  @override
  String get widgetOpacityDescription =>
      'Makes widgets more transparent or more opaque in your home screen.';

  @override
  String get firstDayOfTheWeek => 'Fyrsti dagur vikunar';

  @override
  String get defaultReminderQuestion => 'Hefurðu gert þetta í dag?';

  @override
  String get notes => 'Minnispunktur';

  @override
  String get exampleNotes => '(Valfrjálst)';

  @override
  String get yesOrNoExample =>
      't.d., Vaknaðir þú snemma í dag? Æfðir þú þig? Tefldir þú skák?';

  @override
  String get measurable => 'Mælanlegt';

  @override
  String get measurableExample =>
      't.d., Hversu marga kílómetra hljópstu í dag? Hvað lasstu margar blaðsíður?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 sinnum í viku';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 sinnum á mánuði';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 sinnum á $p2 dögum';
  }

  @override
  String get yesOrNoShortExample => 't.d., Æfa sig';

  @override
  String get color => 'Litur';

  @override
  String get exampleTarget => 't.d., 15';

  @override
  String get measurableShortExample => 't.d., Hlaupa';

  @override
  String get measurableQuestionExample =>
      't.d., Hversu marga kílómetra hljópstu í dag?';

  @override
  String get measurableUnitsExample => 't.d., kílómetra';

  @override
  String get everyMonth => 'Hvern mánuð';

  @override
  String get validationCannotBeBlank => 'Má ekki vera autt';

  @override
  String get today => 'Í dag';

  @override
  String get enter => 'Setja inn';

  @override
  String get noHabits => 'Engar venjur fundust';

  @override
  String get noNumericalHabits => 'Engar mælanlegar venjur fundust';

  @override
  String get noBooleanHabits => 'Engar já/nei venjur fundust';

  @override
  String get increment => 'Hækka';

  @override
  String get decrement => 'Lækka';

  @override
  String get prefSkipTitle => 'Enable skip days';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Toggle twice to add a skip instead of a checkmark. Skips keep your score unchanged and don\'t break your streak.';

  @override
  String get prefUnknownTitle => 'Show question marks for missing data';

  @override
  String get prefUnknownDescription =>
      'Differentiate days without data from actual lapses. To enter a lapse, toggle twice.';

  @override
  String get youAreNowADeveloper => 'You are now a developer';

  @override
  String get activityNotFound => 'No app was found to support this action';

  @override
  String get prefMidnightDelayTitle =>
      'Lengja daginn nokkrar klukkustundir yfir miðnætti';

  @override
  String get prefMidnightDelayDescription =>
      'Bíða til klukkan 03:00 til að sýna nýjan dag. Gagnlegt ef þú ferð að sofa eftir miðnætti. Krefst endurræsingar forritsins.';

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
      other: 'Venjur breyttar',
      one: 'Venju breytt',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habits deleted',
      one: 'Habit deleted',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habits archived',
      one: 'Habit archived',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habits unarchived',
      one: 'Habit unarchived',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eyða venjum?',
      one: 'Eyða venju?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The habits will be permanently deleted. This action cannot be undone.',
      one:
          'The habit will be permanently deleted. This action cannot be undone.',
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
