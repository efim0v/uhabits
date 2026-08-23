// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Esperanto (`eo`).
class L10nEo extends L10n {
  L10nEo([String locale = 'eo']) : super(locale);

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Kutimoj';

  @override
  String get actionSettings => 'Agordoj';

  @override
  String get edit => 'Redakti';

  @override
  String get delete => 'Forigi';

  @override
  String get archive => 'Arĥivo';

  @override
  String get unarchive => 'Elarĥivigi';

  @override
  String get addHabit => 'Aldonu kutimon';

  @override
  String get colorPickerDefaultTitle => 'Ŝanĝi koloron';

  @override
  String get toastHabitCreated => 'Kutimo kreita';

  @override
  String get overview => 'Generala vidado';

  @override
  String get habitStrength => 'Kutimo forteco';

  @override
  String get history => 'Historio';

  @override
  String get clear => 'Liberigi';

  @override
  String get reminder => 'Memorigaĵoj';

  @override
  String get save => 'Konservi';

  @override
  String get streaks => 'Strioj';

  @override
  String get noHabitsFound => 'Vi ne havas aktivajn kutimojn';

  @override
  String get noHabitsLeftToDo => 'You\'re all done for today!';

  @override
  String get longPressToToggle => 'Premu kaj tenu por kontroli aŭ malmarki';

  @override
  String get reminderOff => 'Neaktiva';

  @override
  String get createHabit => 'Krei kutimon';

  @override
  String get editHabit => 'Eldoni kutimon';

  @override
  String get check => 'Kontrolu';

  @override
  String get snooze => 'Poste';

  @override
  String get introTitle1 => 'Bonvenon';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker helpas vin krei kaj konservi bonajn kutimojn.';

  @override
  String get introTitle2 => 'Krei kelkajn novajn kutimojn';

  @override
  String get introDescription2 =>
      'Ĉiutage, post plenumi vian kutimon, metu markostampon en la app.';

  @override
  String get introTitle4 => 'Por atenti vian progreson:';

  @override
  String get introDescription4 =>
      'Detalaj grafikaĵoj montras al vi kiel viaj kutimoj pliboniĝis kun la tempo.';

  @override
  String get interval15Minutes => '15 minutoj';

  @override
  String get interval30Minutes => '30 minutoj';

  @override
  String get interval1Hour => '1 horo';

  @override
  String get interval2Hour => '2 horoj';

  @override
  String get interval4Hour => '4 horoj';

  @override
  String get interval8Hour => '4 horoj';

  @override
  String get interval24Hour => '24 horoj';

  @override
  String get intervalAlwaysAsk => 'Ĉiam demandu';

  @override
  String get intervalCustom => 'Kutimo';

  @override
  String get prefToggleTitle => 'Ŝalti per mallonga gazetaro';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Taksu ĉi tiun aplikaĵon en Google Play';

  @override
  String get prefSendFeedback => 'Sendu reagojn al programisto';

  @override
  String get prefViewSourceCode => 'Vidu fontkodon ĉe GitHub';

  @override
  String get links => 'Ligilo';

  @override
  String get name => 'Nomo';

  @override
  String get settings => 'Agordoj';

  @override
  String get selectSnoozeDelay => 'Elektu dormetigas prokrasti';

  @override
  String get hintTitle => 'Ĉu vi sciis?';

  @override
  String get hintDrag =>
      'Por reordigi la enskribojn, premi kaj tenu la nomon de la kutimo, poste trenu ĝin al la ĝusta loko.';

  @override
  String get hintLandscape =>
      'Vi povas vidi pliajn tagojn enmetante vian telefonon en pejzaĝa reĝimo.';

  @override
  String get habitNotFound => 'Kutimo forigita / ne trovita';

  @override
  String get weekends => 'Semajnfinoj';

  @override
  String get anyWeekday => 'Lundo al vendredo';

  @override
  String get anyDay => 'Io semajntago';

  @override
  String get selectWeekdays => 'Elekti tagojn';

  @override
  String get exportToCsv => 'Eksporti kiel CSV';

  @override
  String get doneLabel => 'Farite';

  @override
  String get clearLabel => 'Liberigi';

  @override
  String get selectHours => 'Elekti horojn';

  @override
  String get selectMinutes => 'Elekti minutojn';

  @override
  String get about => 'Pri programo';

  @override
  String get translators => 'Tradukantoj';

  @override
  String get developers => 'Evoluigantoj';

  @override
  String versionN(String p1) {
    return 'Versio $p1';
  }

  @override
  String get frequency => 'Frekvenco';

  @override
  String get checkmark => 'Markobutono';

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
  String get bestStreaks => 'Plej bonaj strioj';

  @override
  String get everyDay => 'Ĉiu tago';

  @override
  String get everyWeek => 'Ĉiu semajno';

  @override
  String get help => 'Helpo & Ofte Demandite';

  @override
  String get couldNotExport => 'Malsukcesis eksporti datumojn.';

  @override
  String get couldNotImport => 'Malsukcesis importi datumojn.';

  @override
  String get fileNotRecognized => 'Dosiero ne rekonita.';

  @override
  String get habitsImported => 'Kutimoj importitaj sukcese.';

  @override
  String get importData => 'Importi datumojn';

  @override
  String get exportFullBackup => 'Eksporti plenan sekurkopion';

  @override
  String get importDataSummary =>
      'Elportas plenajn sekurkopiojn eksportitajn de ĉi tiu aplikaĵo, same kiel dosierojn generitajn de Tickmate, HabitBull aŭ Rewire. Vidu DPO por pliaj informoj.';

  @override
  String get exportAsCsvSummary =>
      'Generas dosierojn, kiujn oni povas malfermi per kalkultabelaj programoj kiel Microsoft Excel aŭ OpenOffice Calc. Ĉi tiu dosiero ne povas esti importita reen.';

  @override
  String get exportFullBackupSummary =>
      'Generas dosieron, kiu enhavas ĉiujn viajn datumojn. Ĉi tiu dosiero povas esti importita reen.';

  @override
  String get selectPublicBackupFolder => 'Elektu publikan sekurkopi-dosierujon';

  @override
  String get noPublicBackupFolderSelected => 'Neniu dosierujo elektita';

  @override
  String get bugReportFailed => 'Malsukcesis generi raporton pri eraroj.';

  @override
  String get generateBugReport => 'Generu raporton pri eraroj';

  @override
  String get troubleshooting => 'Problemserĉado';

  @override
  String get helpTranslate => 'Helpu traduki ĉi tiun aplikon';

  @override
  String get nightMode => 'Nokta reĝimo';

  @override
  String get usePureBlack => 'Uzu puran nigron en malhela temo';

  @override
  String get pureBlackDescription =>
      'Anstataŭigas grizajn fonojn per pura nigra en malhela temo. Reduktas baterian uzon en telefonoj kun AMOLED-ekrano.';

  @override
  String get interfacePreferences => 'Intervizago';

  @override
  String get reverseDays => 'Reversa ordo de tagoj';

  @override
  String get reverseDaysDescription =>
      'Montri tagojn en inversa ordo sur la ĉefa ekrano.';

  @override
  String get day => 'Tago';

  @override
  String get week => 'Semajno';

  @override
  String get month => 'Monato';

  @override
  String get quarter => 'Jarkvarono';

  @override
  String get year => 'Jaro';

  @override
  String get total => 'Totalo';

  @override
  String get yesOrNo => 'Jes aŭ ne';

  @override
  String everyXDays(int p1) {
    return 'Ĉiujn $p1 tagojn';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Ĉiuj $p1 semajnoj';
  }

  @override
  String get score => 'Poentaroj';

  @override
  String get reminderSound => 'rememor-sonorilo';

  @override
  String get none => 'Nenio';

  @override
  String get filter => 'Filtrilo';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Kaŝi kompletajn';

  @override
  String get hideEntered => 'Hide entered';

  @override
  String get hideArchived => 'Kaŝi arĥivitajn';

  @override
  String get stickyNotifications => 'Faru sciigojn gluaj';

  @override
  String get stickyNotificationsDescription =>
      'Malhelpas, ke sciigoj estu forglititaj.';

  @override
  String get ledNotifications => 'Atentiga lumo';

  @override
  String get ledNotificationsDescription =>
      'Montras palpebrumantan lumon por memorigiloj. Nur havebla en telefonoj kun LED-sciigaj lumoj.';

  @override
  String get repairDatabase => 'Ripari datumbazon';

  @override
  String get databaseRepaired => 'Datumbazon riparita.';

  @override
  String get uncheck => 'Malmarku';

  @override
  String get toggle => 'Ŝalti';

  @override
  String get action => 'Ago';

  @override
  String get habit => 'Kutimo';

  @override
  String get sort => 'Enkursigi';

  @override
  String get manually => 'Mane';

  @override
  String get byName => 'Laŭ nomo';

  @override
  String get byColor => 'Laŭ koloro';

  @override
  String get byScore => 'Laŭ poentaro';

  @override
  String get byStatus => 'By status';

  @override
  String get export => 'Eksporti';

  @override
  String get longPressToEdit => 'Premu kaj tenu por ŝanĝi la valoron';

  @override
  String get value => 'Value';

  @override
  String get calendar => 'Kalendaro:';

  @override
  String get unit => 'Unueco';

  @override
  String get targetType => 'Target Type';

  @override
  String get targetTypeAtLeast => 'At least';

  @override
  String get targetTypeAtMost => 'At most';

  @override
  String get exampleQuestionBoolean => 'ekz. Ĉu vi ekzercis hodiaŭ?';

  @override
  String get question => 'Demando';

  @override
  String get target => 'Celo';

  @override
  String get yes => 'Jes';

  @override
  String get no => 'Ne';

  @override
  String get customizeNotificationSummary =>
      'Ŝanĝu sonon, vibron, lumon kaj aliajn sciigajn agordojn';

  @override
  String get customizeNotification => 'Adaptitaj sciigoj';

  @override
  String get prefViewPrivacy => 'Vidu privatecan politikon';

  @override
  String get viewAllContributors => 'Rigardi ĉiujn kontribuantojn&#8230;';

  @override
  String get database => 'Datumbazo';

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
    return '$p1 times in $p2 days';
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
}
