// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Danish (`da`).
class L10nDa extends L10n {
  L10nDa([String locale = 'da']) : super(locale);

  @override
  String get overview => 'Overblik';

  @override
  String get appName => 'Loop Vane Tracker';

  @override
  String get mainActivityTitle => 'Vaner';

  @override
  String get actionSettings => 'Indstillinger';

  @override
  String get edit => 'Rediger';

  @override
  String get delete => 'Slet';

  @override
  String get archive => 'Arkivér';

  @override
  String get unarchive => 'Fjern fra arkiv';

  @override
  String get addHabit => 'Tilføj vane';

  @override
  String get colorPickerDefaultTitle => 'Skift farve';

  @override
  String get toastHabitCreated => 'Vanen er skabt.';

  @override
  String get habitStrength => 'Vanestyrke';

  @override
  String get history => 'Historie';

  @override
  String get clear => 'Ryd';

  @override
  String get reminder => 'Påmindelse';

  @override
  String get save => 'Gem';

  @override
  String get streaks => 'Streaks';

  @override
  String get noHabitsFound => 'Du har ingen aktive vaner';

  @override
  String get noHabitsLeftToDo => 'Du har klaret alt for i dag!';

  @override
  String get longPressToToggle => 'Tryk og hold nede for at afkrydse';

  @override
  String get reminderOff => 'Fra';

  @override
  String get createHabit => 'Opret vane';

  @override
  String get editHabit => 'Rediger vane';

  @override
  String get check => 'Afkryds';

  @override
  String get snooze => 'Senere';

  @override
  String get introTitle1 => 'Velkommen';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker hjælper dig med at holde gode vaner.';

  @override
  String get introTitle2 => 'Skab nogle nye vaner';

  @override
  String get introDescription2 =>
      'Hver dag, efter at have udført din vane, skal du sætte et flueben i app\'en.';

  @override
  String get introTitle4 => 'Følg dine fremskridt';

  @override
  String get introDescription4 =>
      'Detaljerede grafer viser dig hvordan dine vaner udvikler sig over tid.';

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
  String get interval24Hour => '24 timer';

  @override
  String get intervalAlwaysAsk => 'Spørg altid';

  @override
  String get intervalCustom => 'Brugerdefineret...';

  @override
  String get prefToggleTitle => 'Tjek vaner med kort tryk';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Bedøm denne app på Google Play';

  @override
  String get prefSendFeedback => 'Send feedback til udvikleren';

  @override
  String get prefViewSourceCode => 'Se kildekoden på GitHub';

  @override
  String get links => 'Henvisninger';

  @override
  String get name => 'Navn';

  @override
  String get settings => 'Indstillinger';

  @override
  String get selectSnoozeDelay => 'Vælg snooze-forsinkelse';

  @override
  String get hintTitle => 'Vidste du?';

  @override
  String get hintDrag =>
      'For at omarrangere poster, tryk og hold på navnet på den vane, og træk den til det korrekte sted.';

  @override
  String get hintLandscape =>
      'Du kan se flere dage ved at sætte telefonen i liggende tilstand.';

  @override
  String get habitNotFound => 'Vane slettet / ikke fundet';

  @override
  String get weekends => 'Weekender';

  @override
  String get anyWeekday => 'Mandag til Fredag';

  @override
  String get anyDay => 'En hvilken som helst dag i ugen';

  @override
  String get selectWeekdays => 'Vælg dage';

  @override
  String get exportToCsv => 'Eksporter som CSV';

  @override
  String get doneLabel => 'Færdig';

  @override
  String get clearLabel => 'Fjern';

  @override
  String get selectHours => 'Vælg timer';

  @override
  String get selectMinutes => 'Vælg minutter';

  @override
  String get about => 'Om';

  @override
  String get translators => 'Oversættere';

  @override
  String get developers => 'Udviklere';

  @override
  String versionN(String p1) {
    return 'Version $p1';
  }

  @override
  String get frequency => 'Hyppighed';

  @override
  String get checkmark => 'Afkrydsning';

  @override
  String get checkmarkStackWidget => 'Afkryds stakkontrol';

  @override
  String get frequencyStackWidget => 'Frekvens stakkontrol';

  @override
  String get scoreStackWidget => 'Score stakkontrol';

  @override
  String get historyStackWidget => 'Historik stakkontrol';

  @override
  String get streaksStackWidget => 'Uafbrudt række stakkontrol';

  @override
  String get bestStreaks => 'Bedste streak';

  @override
  String get everyDay => 'Hver dag';

  @override
  String get everyWeek => 'Hver uge';

  @override
  String get help => 'Hjælp & FAQ';

  @override
  String get couldNotExport => 'Kunne ikke eksportere data';

  @override
  String get couldNotImport => 'Kunne ikke importere data';

  @override
  String get fileNotRecognized => 'Fil ikke genkendt.';

  @override
  String get habitsImported => 'Vaner importeret.';

  @override
  String get importData => 'Importer data';

  @override
  String get exportFullBackup => 'Eksporter fuld backup.';

  @override
  String get importDataSummary =>
      'Understøtter fuld backup eksporteret af denne app, samt filer genereret af Tickmate, HabitBull eller Rewire. Se FAQ for mere information.';

  @override
  String get exportAsCsvSummary =>
      'Opretter filer, der kan åbnes af regneark fra Microsoft Excel eller OpenOffice Calc. Denne fil kan ikke importeres tilbage.';

  @override
  String get exportFullBackupSummary =>
      'Opretter en fil, der indeholder alle dine data. Denne fil kan importeres tilbage.';

  @override
  String get selectPublicBackupFolder => 'Vælg offentlig sikkerhedskopimappe';

  @override
  String get noPublicBackupFolderSelected => 'Ingen mappe valgt';

  @override
  String get bugReportFailed => 'Kunne ikke generere fejlrapport.';

  @override
  String get generateBugReport => 'Generer fejlrapport';

  @override
  String get troubleshooting => 'Fejlfinding';

  @override
  String get helpTranslate => 'Hjælpe med at oversætte denne app';

  @override
  String get nightMode => 'Nat-tilstand';

  @override
  String get usePureBlack => 'Brug ren sort i nat-tilstand';

  @override
  String get pureBlackDescription =>
      'Erstatter grå baggrunde med ren sort i nat-tilstand. Reducerer batteriforbruget i telefoner med AMOLED skærm.';

  @override
  String get interfacePreferences => 'Grænseflade';

  @override
  String get reverseDays => 'Omvendt rækkefølge af dage';

  @override
  String get reverseDaysDescription =>
      'Vis dag i omvendt rækkefølge på hovedskærmen';

  @override
  String get day => 'Dag';

  @override
  String get week => 'Uge';

  @override
  String get month => 'Måned';

  @override
  String get quarter => 'Kvartal';

  @override
  String get year => 'År';

  @override
  String get total => 'I alt';

  @override
  String get yesOrNo => 'Ja eller nej';

  @override
  String everyXDays(int p1) {
    return 'Hver $p1 dage';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Hver $p1 uger';
  }

  @override
  String get score => 'Point';

  @override
  String get reminderSound => 'Påmindelse lyd';

  @override
  String get none => 'Ingen';

  @override
  String get filter => 'Filtrer';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Skjul fuldførte';

  @override
  String get hideEntered => 'Hide entered';

  @override
  String get hideArchived => 'Skjul arkiverede';

  @override
  String get stickyNotifications => 'Fastgør notifikationer';

  @override
  String get stickyNotificationsDescription =>
      'Forhindrer notifikationer i at blive swipet væk.';

  @override
  String get ledNotifications => 'Notifikationslys';

  @override
  String get ledNotificationsDescription =>
      'Viser et blinkende lys til påmindelser. Kun tilgængelig i telefoner med LED-notifikationslyskilder.';

  @override
  String get repairDatabase => 'Reparer database';

  @override
  String get databaseRepaired => 'Database repareret.';

  @override
  String get uncheck => 'Fjern afkrydsning';

  @override
  String get toggle => 'Skift mellem';

  @override
  String get action => 'Handling';

  @override
  String get habit => 'Vane';

  @override
  String get sort => 'Sortér';

  @override
  String get manually => 'Manuelt';

  @override
  String get byName => 'Efter navn';

  @override
  String get byColor => 'Efter farve';

  @override
  String get byScore => 'Efter score';

  @override
  String get byStatus => 'Efter status';

  @override
  String get export => 'Eksporter';

  @override
  String get longPressToEdit => 'Tryk-og-hold for at ændre værdien';

  @override
  String get value => 'Value';

  @override
  String get calendar => 'Kalender';

  @override
  String get unit => 'Enhed';

  @override
  String get targetType => 'Target Type';

  @override
  String get targetTypeAtLeast => 'At least';

  @override
  String get targetTypeAtMost => 'At most';

  @override
  String get exampleQuestionBoolean => 'f.eks. Har du trænet i dag?';

  @override
  String get question => 'Spørgsmål';

  @override
  String get target => 'Mål';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nej';

  @override
  String get customizeNotificationSummary =>
      'Skift lyd-, vibrations-, lys- og andre notifikationsindstillinger';

  @override
  String get customizeNotification => 'Tilpas notifikationer';

  @override
  String get prefViewPrivacy => 'Se privatlivspolitik';

  @override
  String get viewAllContributors => 'Se alle bidragsydere…';

  @override
  String get database => 'Database';

  @override
  String get widgetOpacityTitle => 'Gennemsigtighed af widget';

  @override
  String get widgetOpacityDescription =>
      'Gør widgets mere gennemsigtige eller mere uigennemsigtige på din startskærm.';

  @override
  String get firstDayOfTheWeek => 'Første dag i ugen';

  @override
  String get defaultReminderQuestion => 'Har du fuldført denne vane i dag?';

  @override
  String get notes => 'Noter';

  @override
  String get exampleNotes => '(Valgfrit)';

  @override
  String get yesOrNoExample =>
      'F.eks. vågnede du tidligt i dag? Har du motioneret? Spillede du skak?';

  @override
  String get measurable => 'Målbar';

  @override
  String get measurableExample =>
      'f.eks Hvor mange kilometer kørte du i dag? Hvor mange sider læste du?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 gange om ugen';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 gange om måneden';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 gange på $p2 dage';
  }

  @override
  String get yesOrNoShortExample => 'f.eks. Motion';

  @override
  String get color => 'Farve';

  @override
  String get exampleTarget => 'f.eks. 15';

  @override
  String get measurableShortExample => 'f.eks. Løb';

  @override
  String get measurableQuestionExample =>
      'F.eks. Hvor mange kilometer har du løbet i dag?';

  @override
  String get measurableUnitsExample => 'f.eks. kilometer';

  @override
  String get everyMonth => 'Hver måned';

  @override
  String get validationCannotBeBlank => 'skal udfyldes';

  @override
  String get today => 'I dag';

  @override
  String get enter => 'Angiv';

  @override
  String get noHabits => 'Ingen vaner fundet';

  @override
  String get noNumericalHabits => 'Ingen målbare vaner fundet';

  @override
  String get noBooleanHabits => 'Ingen ja-eller-nej vaner fundet';

  @override
  String get increment => 'Forøgelse';

  @override
  String get decrement => 'Formindskelse';

  @override
  String get prefSkipTitle => 'Slå overspring af dage til';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Skift to gange for at tilføje et overspring i stedet for et flueben. Spring over holder din score uændret og bryder ikke din række.';

  @override
  String get prefUnknownTitle => 'Vis spørgsmålstegn for manglende data';

  @override
  String get prefUnknownDescription =>
      'Differentiér dage uden data fra faktiske udeladelser. For at indtaste en udeladelse, skiftes to gange.';

  @override
  String get youAreNowADeveloper => 'Du er nu udvikler';

  @override
  String get activityNotFound =>
      'Ingen app fundet til at understøtte denne handling';

  @override
  String get prefMidnightDelayTitle =>
      'Forlæng dagen et par timer efter midnat';

  @override
  String get prefMidnightDelayDescription =>
      'Vent til 3:00 for at vise en ny dag. Nyttigt, hvis du typisk går i seng efter midnat. Kræver genstart af app.';

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
      other: 'Vanerne er ændret',
      one: 'Vanen er ændret',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vanerne er slettet',
      one: 'Vanen er slettet',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vanerne er arkiveret',
      one: 'Vanen er arkiveret',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vaner taget ud fra arkiv',
      one: 'Vane taget ud fra arkiv',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slet vaner?',
      one: 'Slet vane?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vanerne vil blive slettet permanent. Denne handling kan ikke fortrydes.',
      one:
          'Vanen vil blive slettet permanent. Denne handling kan ikke fortrydes.',
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
  String get abstinenceOfRecord => 'of the record';

  @override
  String get abstinenceOfPrevious => 'of the previous run';

  @override
  String get abstinenceIsRecord => 'record';

  @override
  String get abstinenceLapsesTotal => 'lapses';
}
