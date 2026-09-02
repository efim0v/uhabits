// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Norwegian (`no`).
class L10nNo extends L10n {
  L10nNo([String locale = 'no']) : super(locale);

  @override
  String get overview => 'Oversikt';

  @override
  String get appName => 'Loop Vaneoversikt';

  @override
  String get mainActivityTitle => 'Vaner';

  @override
  String get actionSettings => 'Innstillinger';

  @override
  String get edit => 'Redigér';

  @override
  String get delete => 'Slett';

  @override
  String get archive => 'Arkivér';

  @override
  String get unarchive => 'Uarkivér';

  @override
  String get addHabit => 'Legg til vane';

  @override
  String get colorPickerDefaultTitle => 'Endr farge';

  @override
  String get toastHabitCreated => 'Vane laget';

  @override
  String get habitStrength => 'Vanestyrke';

  @override
  String get history => 'Logg';

  @override
  String get clear => 'Fjern';

  @override
  String get reminder => 'Påminnelse';

  @override
  String get save => 'Lagr';

  @override
  String get streaks => 'Gjentakelser';

  @override
  String get noHabitsFound => 'Du har ingen aktive vaner';

  @override
  String get noHabitsLeftToDo => 'You\'re all done for today!';

  @override
  String get longPressToToggle => 'Trykk og hold for å sjekke eller usjekke';

  @override
  String get reminderOff => 'Av';

  @override
  String get createHabit => 'Lag vane';

  @override
  String get editHabit => 'Redigér vane';

  @override
  String get check => 'Sjekk';

  @override
  String get snooze => 'Senere';

  @override
  String get introTitle1 => 'Velkommen';

  @override
  String get introDescription1 =>
      'Loop Vaneoversikt hjelper deg med å lage og beholde gode vaner.';

  @override
  String get introTitle2 => 'Lag noen nye vaner';

  @override
  String get introDescription2 =>
      'Hver dag, etter du utfører vanen din, sett en hake på appen.';

  @override
  String get introTitle4 => 'Hold oversikt over fremgangen din';

  @override
  String get introDescription4 =>
      'Detaljerte grafer viser deg hvordan vanene dine forbedrer seg over tid.';

  @override
  String get interval15Minutes => '15 minutter';

  @override
  String get interval30Minutes => '30 minutter';

  @override
  String get interval1Hour => '1 time';

  @override
  String get interval2Hour => '2 timer';

  @override
  String get interval4Hour => '4 timer';

  @override
  String get interval8Hour => '8 timer';

  @override
  String get interval24Hour => '1 døgn';

  @override
  String get intervalAlwaysAsk => 'Always ask';

  @override
  String get intervalCustom => 'Egendefinert...';

  @override
  String get prefToggleTitle => 'Veksl med enkelttrykk';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Vurdér denne appen på Google Play';

  @override
  String get prefSendFeedback => 'Send tilbakemelding til utviklerne';

  @override
  String get prefViewSourceCode => 'Vis kildekode på GitHub';

  @override
  String get links => 'Lenker';

  @override
  String get name => 'Navn';

  @override
  String get settings => 'Innstillinger';

  @override
  String get selectSnoozeDelay => 'Select snooze delay';

  @override
  String get hintTitle => 'Visste du at?';

  @override
  String get hintDrag =>
      'For å sortere innleggene, trykk og hold på navnet til vanen, deretter dra den til det korrekte stedet.';

  @override
  String get hintLandscape =>
      'Du kan se flere dager ved å sette telefonen din i landskapsmodus.';

  @override
  String get habitNotFound => 'Vane slettet / ikke funnet';

  @override
  String get weekends => 'Helger';

  @override
  String get anyWeekday => 'Hverdager';

  @override
  String get anyDay => 'Hvilken som helst dag i uken';

  @override
  String get selectWeekdays => 'Velg dager';

  @override
  String get exportToCsv => 'Eksportér som CSV';

  @override
  String get doneLabel => 'Ferdig';

  @override
  String get clearLabel => 'Fjern';

  @override
  String get selectHours => 'Velg timer';

  @override
  String get selectMinutes => 'Velg minutter';

  @override
  String get about => 'Om';

  @override
  String get translators => 'Translatører';

  @override
  String get developers => 'Utviklere';

  @override
  String versionN(String p1) {
    return 'Versjon $p1';
  }

  @override
  String get frequency => 'Hyppighet';

  @override
  String get checkmark => 'Hake';

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
  String get bestStreaks => 'Beste gjentakelser';

  @override
  String get everyDay => 'Hver dag';

  @override
  String get everyWeek => 'Hver uke';

  @override
  String get help => 'Hjelp og FAQ';

  @override
  String get couldNotExport => 'Mislyktes i å eksportere data.';

  @override
  String get couldNotImport => 'Mislyktes i å importere data.';

  @override
  String get fileNotRecognized => 'Fil ikke gjenkjent.';

  @override
  String get habitsImported => 'Vaner suksessfullt importert.';

  @override
  String get importData => 'Importér data';

  @override
  String get exportFullBackup => 'Eksportér hel sikkerhetskopi';

  @override
  String get importDataSummary =>
      'Støtter hele sikkerhetskopier eksportert av denne appen, i tillegg til filer generert av Tickmate, HabitBull, og Rewire. Sjekk ut FAQ for mer informasjon.';

  @override
  String get exportAsCsvSummary =>
      'Genererer filer som kan bli åpnet av regnearkprogrammer som Microsoft Excel og OpenOffice Calc. Disse filene kan ikke importeres tilbake.';

  @override
  String get exportFullBackupSummary =>
      'Genererer en fil som inneholder all dataen din. Denne filen kan ikke importeres tilbake.';

  @override
  String get selectPublicBackupFolder => 'Velg offentlig sikkerhetskopimappe';

  @override
  String get noPublicBackupFolderSelected => 'Ingen mappe valgt';

  @override
  String get bugReportFailed => 'Mislyktes i å generere feilrapport.';

  @override
  String get generateBugReport => 'Generér feilrapport';

  @override
  String get troubleshooting => 'Feilsøkning';

  @override
  String get helpTranslate => 'Hjelp med å oversette denne appen';

  @override
  String get nightMode => 'Nattmodus';

  @override
  String get usePureBlack => 'Bruk batterisparing i nattmodus';

  @override
  String get pureBlackDescription =>
      'Bytter ut grå bakgunner med helt svarte i nattmodus. Reduserer betteribruk hos telefoner med AMOLED-skjerm.';

  @override
  String get interfacePreferences => 'Grensesnitt';

  @override
  String get reverseDays => 'Omvendt dagsrekkefølge';

  @override
  String get reverseDaysDescription =>
      'Vis dager i omvendt rekkefølge på hovedmenyen';

  @override
  String get day => 'Dag';

  @override
  String get week => 'Uke';

  @override
  String get month => 'Måned';

  @override
  String get quarter => 'Kvarter';

  @override
  String get year => 'År';

  @override
  String get total => 'Totalt';

  @override
  String get yesOrNo => 'Ja / Nei';

  @override
  String everyXDays(int p1) {
    return 'Hver $p1. dag';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Hver $p1. uke';
  }

  @override
  String get score => 'Poengsum';

  @override
  String get reminderSound => 'Påminnelseslyd';

  @override
  String get none => 'Ingen';

  @override
  String get filter => 'Filtrér';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Gjem fullførte';

  @override
  String get hideEntered => 'Hide entered';

  @override
  String get hideArchived => 'Gjem arkiverte';

  @override
  String get stickyNotifications => 'Gjør varslinger klebrige';

  @override
  String get stickyNotificationsDescription =>
      'Forhindrer varslinger fra å bli sveipet vekk.';

  @override
  String get ledNotifications => 'Notification light';

  @override
  String get ledNotificationsDescription =>
      'Shows a blinking light for reminders. Only available in phones with LED notification lights.';

  @override
  String get repairDatabase => 'Reparér database';

  @override
  String get databaseRepaired => 'Database reparert.';

  @override
  String get uncheck => 'Usjekk';

  @override
  String get toggle => 'Veksl';

  @override
  String get action => 'Handling';

  @override
  String get habit => 'Vane';

  @override
  String get sort => 'Sortér';

  @override
  String get manually => 'Manuelt';

  @override
  String get byName => 'Etter navn';

  @override
  String get byColor => 'Etter farge';

  @override
  String get byScore => 'Etter poengsum';

  @override
  String get byStatus => 'By status';

  @override
  String get export => 'Eksportér';

  @override
  String get longPressToEdit => 'Press-and-hold to change the value';

  @override
  String get value => 'Value';

  @override
  String get calendar => 'Calendar';

  @override
  String get unit => 'Unit';

  @override
  String get targetType => 'Target Type';

  @override
  String get targetTypeAtLeast => 'At least';

  @override
  String get targetTypeAtMost => 'At most';

  @override
  String get exampleQuestionBoolean => 'e.g. Did you exercise today?';

  @override
  String get question => 'Spørsmål';

  @override
  String get target => 'Target';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get customizeNotificationSummary =>
      'Change sound, vibration, light and other notification settings';

  @override
  String get customizeNotification => 'Customize notifications';

  @override
  String get prefViewPrivacy => 'View privacy policy';

  @override
  String get viewAllContributors => 'View all contributors…';

  @override
  String get database => 'Database';

  @override
  String get widgetOpacityTitle => 'Widget opacity';

  @override
  String get widgetOpacityDescription =>
      'Makes widgets more transparent or more opaque in your home screen.';

  @override
  String get firstDayOfTheWeek => 'First day of the week';

  @override
  String get defaultReminderQuestion => 'Have you completed this habit today?';

  @override
  String get notes => 'Notes';

  @override
  String get exampleNotes => '(Optional)';

  @override
  String get yesOrNoExample =>
      'e.g. Did you wake up early today? Did you exercise? Did you play chess?';

  @override
  String get measurable => 'Measurable';

  @override
  String get measurableExample =>
      'e.g. How many miles did you run today? How many pages did you read?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 times per week';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 times per month';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 ganger på $p2 dager';
  }

  @override
  String get yesOrNoShortExample => 'e.g. Exercise';

  @override
  String get color => 'Color';

  @override
  String get exampleTarget => 'e.g. 15';

  @override
  String get measurableShortExample => 'e.g. Run';

  @override
  String get measurableQuestionExample =>
      'e.g. How many miles did you run today?';

  @override
  String get measurableUnitsExample => 'e.g. miles';

  @override
  String get everyMonth => 'Every month';

  @override
  String get validationCannotBeBlank => 'Cannot be blank';

  @override
  String get today => 'Today';

  @override
  String get enter => 'Enter';

  @override
  String get noHabits => 'No habits found';

  @override
  String get noNumericalHabits => 'No measurable habits found';

  @override
  String get noBooleanHabits => 'No yes-or-no habits found';

  @override
  String get increment => 'Increment';

  @override
  String get decrement => 'Decrement';

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
  String get prefMidnightDelayTitle => 'Extend day a few hours past midnight';

  @override
  String get prefMidnightDelayDescription =>
      'Wait until 3:00 AM to show a new day. Useful if you typically go to sleep after midnight. Requires app restart.';

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
      other: 'Habits changed',
      one: 'Habit changed',
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
      other: 'Delete habits?',
      one: 'Delete habit?',
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
  String get abstinenceHabitType => 'Freedom';

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
  String get abstinenceGoalNever => 'Not once';

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
  String abstinenceDurationSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '$count second',
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
