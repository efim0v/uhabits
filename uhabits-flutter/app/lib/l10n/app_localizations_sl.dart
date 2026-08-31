// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class L10nSl extends L10n {
  L10nSl([String locale = 'sl']) : super(locale);

  @override
  String get overview => 'Pregled';

  @override
  String get appName => 'Loop Sledilnik Navad';

  @override
  String get mainActivityTitle => 'Navade';

  @override
  String get actionSettings => 'Nastavitve';

  @override
  String get edit => 'Uredi';

  @override
  String get delete => 'Izbriši';

  @override
  String get archive => 'Arhiviraj';

  @override
  String get unarchive => 'Odarhiviraj';

  @override
  String get addHabit => 'Dodaj navado';

  @override
  String get colorPickerDefaultTitle => 'Spremeni barvo';

  @override
  String get toastHabitCreated => 'Navada ustvarjena';

  @override
  String get habitStrength => 'Moč navade';

  @override
  String get history => 'Zgodovina';

  @override
  String get clear => 'Počisti';

  @override
  String get reminder => 'Opomnik';

  @override
  String get save => 'Shrani';

  @override
  String get streaks => 'Serije';

  @override
  String get noHabitsFound => 'Nimate aktivnih navad';

  @override
  String get noHabitsLeftToDo => 'Za danes ste končali!';

  @override
  String get longPressToToggle =>
      'Pritisnite-in-držite, da označite ali odznačite';

  @override
  String get reminderOff => 'Izključeno';

  @override
  String get createHabit => 'Ustvari navado';

  @override
  String get editHabit => 'Spremeni navado';

  @override
  String get check => 'Označi';

  @override
  String get snooze => 'Kasneje';

  @override
  String get introTitle1 => 'Dobrodošli';

  @override
  String get introDescription1 =>
      'Loop Sledilnik Navad vam pomaga ustvariti in vzdrževati dobre navade.';

  @override
  String get introTitle2 => 'Ustvari nekaj novih navad';

  @override
  String get introDescription2 =>
      'Vsak dan, potem ko opravite vašo navado, vnesite kljukico v aplikacijo.';

  @override
  String get introTitle4 => 'Spremljaj svoj napredek';

  @override
  String get introDescription4 =>
      'Podrobni grafi vam pokažejo kako so se skozi čas vaše navede izboljšale.';

  @override
  String get interval15Minutes => '15 minut';

  @override
  String get interval30Minutes => '30 minut';

  @override
  String get interval1Hour => '1 ura';

  @override
  String get interval2Hour => '2 uri';

  @override
  String get interval4Hour => '4 ure';

  @override
  String get interval8Hour => '8 ur';

  @override
  String get interval24Hour => '24 ur';

  @override
  String get intervalAlwaysAsk => 'Vedno vprašaj';

  @override
  String get intervalCustom => 'Po meri...';

  @override
  String get prefToggleTitle => 'Preklopi ponovitve s kratkim pritiskom';

  @override
  String get prefToggleDescription2 =>
      'Postavite kljukice z enim dotikom namesto s pritiskom in držanjem.';

  @override
  String get prefRateThisApp => 'Oceni to aplikacijo na Google Play';

  @override
  String get prefSendFeedback => 'Pošlji povratne informacije razvijalcem';

  @override
  String get prefViewSourceCode => 'Poglej izvorno kodo na GitHub';

  @override
  String get links => 'Povezave';

  @override
  String get name => 'Ime';

  @override
  String get settings => 'Nastavitve';

  @override
  String get selectSnoozeDelay => 'Izberite zakasnitev dremeža';

  @override
  String get hintTitle => 'Ali ste vedeli?';

  @override
  String get hintDrag =>
      'Če želite preurediti vnose, pritisnite-in-držite na ime navade, nato pa jo povlecite na željeno mestu.';

  @override
  String get hintLandscape =>
      'Ogledate si lahko več dni, s tem da telefon postavite v ležeči načinu.';

  @override
  String get habitNotFound => 'Izbrisana navada / ni najdena';

  @override
  String get weekends => 'Vikendi';

  @override
  String get anyWeekday => 'Ponedeljek do Petka';

  @override
  String get anyDay => 'Vsak dan v tednu';

  @override
  String get selectWeekdays => 'Izberi dni';

  @override
  String get exportToCsv => 'Izvozi v CSV';

  @override
  String get doneLabel => 'Končano';

  @override
  String get clearLabel => 'Počisti';

  @override
  String get selectHours => 'Izberi ure';

  @override
  String get selectMinutes => 'Izberi minute';

  @override
  String get about => 'O aplikaciji';

  @override
  String get translators => 'Prevajalci';

  @override
  String get developers => 'Razvijalci';

  @override
  String versionN(String p1) {
    return 'Verzija $p1';
  }

  @override
  String get frequency => 'Pogostost';

  @override
  String get checkmark => 'Kljukica';

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
  String get bestStreaks => 'Najboljša serija';

  @override
  String get everyDay => 'Vsak dan';

  @override
  String get everyWeek => 'Vsak teden';

  @override
  String get help => 'Pomoč & Pogosta vprašanja';

  @override
  String get couldNotExport => 'Neuspešen izvoz podatkov.';

  @override
  String get couldNotImport => 'Neuspešen uvoz podatkov.';

  @override
  String get fileNotRecognized => 'Datoteka ni bila prepoznana.';

  @override
  String get habitsImported => 'Navade uspešno uvožene.';

  @override
  String get importData => 'Uvozi podatke';

  @override
  String get exportFullBackup => 'Izvozi popolno varnostno kopijo';

  @override
  String get importDataSummary =>
      'Podpira polne varnostne kopije izvožene iz te aplikacije, kakor tudi datoteke, ki jih ustvari Tickmate, HabitBull ali Rewire. Glej Pogosta vprašanja za več informacij.';

  @override
  String get exportAsCsvSummary =>
      'Generirane datoteke, ki se lahko odprejo s programsko opremo za preglednice, kot je Microsoft Excel ali OpenOffice Calc. Te datoteke ni mogoče uvoziti nazaj.';

  @override
  String get exportFullBackupSummary =>
      'Ustvari datoteko, ki vsebuje vse podatke. To datoteko lahko nato uvozite nazaj.';

  @override
  String get selectPublicBackupFolder =>
      'Izberite javno mapo za varnostne kopije';

  @override
  String get noPublicBackupFolderSelected => 'Mapa ni izbrana';

  @override
  String get bugReportFailed => 'Neuspeh pri ustvarjanju poročila o napakah';

  @override
  String get generateBugReport => 'Ustvari poročilo o napakah';

  @override
  String get troubleshooting => 'Odpravljanje napak';

  @override
  String get helpTranslate => 'Pomagajte prevesti to aplikacijo';

  @override
  String get nightMode => 'Nočni način';

  @override
  String get usePureBlack => 'Uporabite popolno črnino v nočnem načinu';

  @override
  String get pureBlackDescription =>
      'Zamenja siva ozadja s popolno črnino v nočnem načinu. Zmanjša porabo baterije na telefonih z AMOLED zasloni.';

  @override
  String get interfacePreferences => 'Vmesnik';

  @override
  String get reverseDays => 'Zamenjaj vrstni red dni';

  @override
  String get reverseDaysDescription =>
      'Prikaži dni v obratnem vrstnem redu na glavnem zaslonu';

  @override
  String get day => 'Dan';

  @override
  String get week => 'Teden';

  @override
  String get month => 'Mesec';

  @override
  String get quarter => 'Četrtletje';

  @override
  String get year => 'Leto';

  @override
  String get total => 'Skupaj';

  @override
  String get yesOrNo => 'Da ali Ne';

  @override
  String everyXDays(int p1) {
    return 'Vsakih $p1 dni';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Vsakih $p1 tednov';
  }

  @override
  String get score => 'Ocena';

  @override
  String get reminderSound => 'Zvok opomnika';

  @override
  String get none => 'Noben';

  @override
  String get filter => 'Filter';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Skrij končane';

  @override
  String get hideEntered => 'Skrij vneseno';

  @override
  String get hideArchived => 'Skrij arhivirane';

  @override
  String get stickyNotifications => 'Naaredi obvestila lepljiva';

  @override
  String get stickyNotificationsDescription =>
      'Preprečuje, da lahko obvestila povlečete stran.';

  @override
  String get ledNotifications => 'Lučka za obvestila';

  @override
  String get ledNotificationsDescription =>
      'Prikaže utripajočo luč za opomnike. Na voljo samo v telefonih z LED lučkami za obvestila.';

  @override
  String get repairDatabase => 'Popravi podatkovno zbirko';

  @override
  String get databaseRepaired => 'Podatkovna zbirka popravljena.';

  @override
  String get uncheck => 'Odznači';

  @override
  String get toggle => 'Preklopi';

  @override
  String get action => 'Dejanje';

  @override
  String get habit => 'Navada';

  @override
  String get sort => 'Razvrsti';

  @override
  String get manually => 'Ročno';

  @override
  String get byName => 'Po imenu';

  @override
  String get byColor => 'Po barvi';

  @override
  String get byScore => 'Po rezultatu';

  @override
  String get byStatus => 'Po statusu';

  @override
  String get export => 'Izvozi';

  @override
  String get longPressToEdit => 'Pritisnite in držite, da spremenite vrednost';

  @override
  String get value => 'Vrednost';

  @override
  String get calendar => 'Koledar';

  @override
  String get unit => 'Enota';

  @override
  String get targetType => 'Vrsta cilja';

  @override
  String get targetTypeAtLeast => 'Vsaj';

  @override
  String get targetTypeAtMost => 'Največ';

  @override
  String get exampleQuestionBoolean => 'npr. Ste danes telovadili?';

  @override
  String get question => 'Vprašanje';

  @override
  String get target => 'Cilj';

  @override
  String get yes => 'Da';

  @override
  String get no => 'Ne';

  @override
  String get customizeNotificationSummary =>
      'Spremenite nastavitve zvoka, vibriranja, svetlobe in drugih obvestil';

  @override
  String get customizeNotification => 'Prilagoditve obvestil';

  @override
  String get prefViewPrivacy => 'Oglejte si pravilnik o zasebnosti';

  @override
  String get viewAllContributors => 'Poglej vse sodelavce…';

  @override
  String get database => 'Baza podatkov';

  @override
  String get widgetOpacityTitle => 'Prosojnost pripomočka';

  @override
  String get widgetOpacityDescription =>
      'Pripomočke naredi bolj pregledne ali bolj neprozorne na domačem zaslonu.';

  @override
  String get firstDayOfTheWeek => 'Prvi dan v tednu';

  @override
  String get defaultReminderQuestion => 'Ste danes dokončali to navado?';

  @override
  String get notes => 'Opombe';

  @override
  String get exampleNotes => '(Neobvezno)';

  @override
  String get yesOrNoExample =>
      'npr. Ste se danes zgodaj zbudili? Ste telovadili? Ste igrali šah?';

  @override
  String get measurable => 'Merljivo';

  @override
  String get measurableExample =>
      'npr. Koliko kilometrov ste pretekli danes? Koliko strani ste prebrali?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 krat na teden';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 krat na mesec';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 krat v $p2 dni';
  }

  @override
  String get yesOrNoShortExample => 'npr. Vadba';

  @override
  String get color => 'Barva';

  @override
  String get exampleTarget => 'npr. 15';

  @override
  String get measurableShortExample => 'npr. Tek';

  @override
  String get measurableQuestionExample =>
      'npr. Koliko kilometrov ste pretekli danes?';

  @override
  String get measurableUnitsExample => 'npr. km';

  @override
  String get everyMonth => 'Vsak mesec';

  @override
  String get validationCannotBeBlank => 'Ne sme biti prazno';

  @override
  String get today => 'Danes';

  @override
  String get enter => 'Vnesi';

  @override
  String get noHabits => 'Ni najdenih navad';

  @override
  String get noNumericalHabits => 'Ni najdenih merljivih navad';

  @override
  String get noBooleanHabits => 'Ni najdenih da ali ne navad';

  @override
  String get increment => 'Povečaj';

  @override
  String get decrement => 'Zmanjšaj';

  @override
  String get prefSkipTitle => 'Omogoči preskok dni';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Dvakrat preklopite, da dodate preskok namesto kljukice. Preskoki ohranjajo vaš rezultat nespremenjen in ne prekinejo vašega niza.';

  @override
  String get prefUnknownTitle => 'Pokaži vprašaj za manjkajoče podatke';

  @override
  String get prefUnknownDescription =>
      'Razlikujte dneve brez podatkov od dejanskih zamud. Če želite vnesti presledek, dvakrat preklopite.';

  @override
  String get youAreNowADeveloper => 'Zdaj ste razvijalec';

  @override
  String get activityNotFound =>
      'Najdena ni bila nobena aplikacija, ki bi podpirala to dejanje';

  @override
  String get prefMidnightDelayTitle => 'Podaljšajte dan nekaj ur čez polnoč';

  @override
  String get prefMidnightDelayDescription =>
      'Počakajte do 3.00, da prikažete nov dan. Uporabno, če greste običajno spat po polnoči. Zahteva ponovni zagon aplikacije.';

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
      other: 'Navade spremenjene',
      few: 'Navade spremenjene',
      two: 'Navadi spremenjene',
      one: 'Navada spremenjena',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navade izbrisane',
      few: 'Navade izbrisane',
      two: 'Navadi izbrisane',
      one: 'Navada izbrisana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navade arhivirana',
      few: 'Navade arhivirana',
      two: 'Navadi arhivirani',
      one: 'Navada arhivirana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navade nearhivirane',
      few: 'Navade nearhivirane',
      two: 'Navadi nearhivirani',
      one: 'Navada nearhivirana',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Izbriši navade?',
      few: 'Izbriši navade?',
      two: 'Izbriši navadi?',
      one: 'Izbriši navado?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Navade bodo trajno izbrisane. Tega dejanja ni mogoče razveljaviti.',
      few: 'Navade bodo trajno izbrisane. Tega dejanja ni mogoče razveljaviti.',
      two: 'Navadi bodo trajno izbrisani. Tega dejanja ni mogoče razveljaviti.',
      one: 'Navada bo trajno izbrisana. Tega dejanja ni mogoče razveljaviti.',
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
