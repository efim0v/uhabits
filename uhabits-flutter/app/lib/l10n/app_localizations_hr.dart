// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class L10nHr extends L10n {
  L10nHr([String locale = 'hr']) : super(locale);

  @override
  String get overview => 'Pregled';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Navike';

  @override
  String get actionSettings => 'Postavke';

  @override
  String get edit => 'Uredi';

  @override
  String get delete => 'Izbriši';

  @override
  String get archive => 'Arhiviraj';

  @override
  String get unarchive => 'Dearhiviraj';

  @override
  String get addHabit => 'Dodaj naviku';

  @override
  String get colorPickerDefaultTitle => 'Promijeni boju';

  @override
  String get toastHabitCreated => 'Navika je stvorena';

  @override
  String get habitStrength => 'Snaga navike';

  @override
  String get history => 'Povijest';

  @override
  String get clear => 'Očisti';

  @override
  String get reminder => 'Podsjetnik';

  @override
  String get save => 'Spremi';

  @override
  String get streaks => 'Niz';

  @override
  String get noHabitsFound => 'Nemate aktivnih navika';

  @override
  String get noHabitsLeftToDo => 'Navike za danas su završene';

  @override
  String get longPressToToggle =>
      'Pritisnite i držite za označavanje ili odznačavanje.';

  @override
  String get reminderOff => 'Isključen';

  @override
  String get createHabit => 'Stvori naviku';

  @override
  String get editHabit => 'Uredi naviku';

  @override
  String get check => 'Potvrdi';

  @override
  String get snooze => 'Kasnije';

  @override
  String get introTitle1 => 'Dobrodošli';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker vam pomaže stvoriti i održavati dobre navike.';

  @override
  String get introTitle2 => 'Stvorite neke nove navike';

  @override
  String get introDescription2 =>
      'Svaki dan, nakon izvođenja vaše navike, postavite \"kvačicu\" u aplikaciji.';

  @override
  String get introTitle4 => 'Pratite svoj napredak';

  @override
  String get introDescription4 =>
      'Detaljni grafovi vam prikazuju kako se vaše navike poboljšavaju kroz vrijeme.';

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
  String get intervalAlwaysAsk => 'Uvijek pitaj';

  @override
  String get intervalCustom => 'Prilagođeno …';

  @override
  String get prefToggleTitle => 'Označi ponavljanja sa kratkim pritisk.';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Ocijeni ovu aplikaciju na Google Playu';

  @override
  String get prefSendFeedback => 'Pošalji povratne informacije raz. programeru';

  @override
  String get prefViewSourceCode => 'Pogledaj izvorni kod na GitHubu';

  @override
  String get links => 'Poveznice';

  @override
  String get name => 'Naziv';

  @override
  String get settings => 'Postavke';

  @override
  String get selectSnoozeDelay => 'Odaberi vrijeme odgode';

  @override
  String get hintTitle => 'Jeste li znali?';

  @override
  String get hintDrag =>
      'Za razmještanje unosa, pritisnite i držite naziv navike, pa ih premjestite na točno mjesto.';

  @override
  String get hintLandscape =>
      'Možete vidjeti više dana prebacivanjem uređaja u vodoravnu orijentaciju.';

  @override
  String get habitNotFound => 'Navika je izbrisana / nije pronađena';

  @override
  String get weekends => 'Vikendi';

  @override
  String get anyWeekday => 'Ponedjeljak do Petak';

  @override
  String get anyDay => 'Bilo koji dan u tjednu';

  @override
  String get selectWeekdays => 'Odaberi dane';

  @override
  String get exportToCsv => 'Izvezi kao CSV';

  @override
  String get doneLabel => 'Dovršeno';

  @override
  String get clearLabel => 'Očisti';

  @override
  String get selectHours => 'Odaberi sate';

  @override
  String get selectMinutes => 'Odaberite minute';

  @override
  String get about => 'O aplikaciji';

  @override
  String get translators => 'Prevoditelji';

  @override
  String get developers => 'Razvojni programeri';

  @override
  String versionN(String p1) {
    return 'Verzija $p1';
  }

  @override
  String get frequency => 'Učestalost';

  @override
  String get checkmark => 'Kvačica';

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
  String get bestStreaks => 'Najbolji nizovi';

  @override
  String get everyDay => 'Svaki dan';

  @override
  String get everyWeek => 'Svaki tjedan';

  @override
  String get help => 'Pomoć i pitanja';

  @override
  String get couldNotExport => 'Izvoz podataka nije uspio.';

  @override
  String get couldNotImport => 'Uvoz podataka nije uspio.';

  @override
  String get fileNotRecognized => 'Datoteka nije prepoznata.';

  @override
  String get habitsImported => 'Navike su uspješno uvezene.';

  @override
  String get importData => 'Uvezi podatke';

  @override
  String get exportFullBackup => 'Izvezi sigurnosnu kopiju';

  @override
  String get importDataSummary =>
      'Podržava sigurnosne kopije izvezene iz ove aplikacije, isto kao i datoteke generirane u Tickmate, HabitBull i Rewire. Pogledajte Pomoć i pitanja za više informacija.';

  @override
  String get exportAsCsvSummary =>
      'Generira datoteke koje se mogu otvarati programima za tablice kao što su Microsoft Excel ili OpenOffice Calc. Ova datoteka se ne može uvoziti.';

  @override
  String get exportFullBackupSummary =>
      'Generira datoteku koja sadrži sve vaše podatke. Ova datoteka se može uvoziti.';

  @override
  String get selectPublicBackupFolder =>
      'Odaberite javnu mapu sigurnosne kopije';

  @override
  String get noPublicBackupFolderSelected => 'Nije odabrana nijedna mapa';

  @override
  String get bugReportFailed => 'Generiranje izvješća o pogrešci nije uspjelo.';

  @override
  String get generateBugReport => 'Generiraj izvješće o pogreški';

  @override
  String get troubleshooting => 'Rješavanje problema';

  @override
  String get helpTranslate => 'Pomozi prevesti ovu aplikaciju';

  @override
  String get nightMode => 'Noćni način';

  @override
  String get usePureBlack => 'Koristi crnu boju za noćni način';

  @override
  String get pureBlackDescription =>
      'Zamjenjuje sivu pozadinu sa crnom u noćnom načinu. To smanjuje potrošnju bateriju na uređajima s AMOLED zaslonima.';

  @override
  String get interfacePreferences => 'Sučelje';

  @override
  String get reverseDays => 'Obrnuti poredak dana';

  @override
  String get reverseDaysDescription =>
      'Prikažite dane obrnutim redom na glavnom zaslonu';

  @override
  String get day => 'Dan';

  @override
  String get week => 'Tjedan';

  @override
  String get month => 'Mjesec';

  @override
  String get quarter => 'Četvrtina';

  @override
  String get year => 'Godina';

  @override
  String get total => 'Ukupno';

  @override
  String get yesOrNo => 'Da ili Ne';

  @override
  String everyXDays(int p1) {
    return 'Svaka $p1 dana';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Svaka $p1 tjedna';
  }

  @override
  String get score => 'Rezultat';

  @override
  String get reminderSound => 'Zvuk podsjetnika';

  @override
  String get none => 'Nijedan';

  @override
  String get filter => 'Filtar';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Sakrij završeno';

  @override
  String get hideEntered => 'Sakrij unesene';

  @override
  String get hideArchived => 'Sakrij arhivirano';

  @override
  String get stickyNotifications => 'Učini obavijesti trajnima';

  @override
  String get stickyNotificationsDescription =>
      'Spriječava da se obavijesti zanemare.';

  @override
  String get ledNotifications => 'Svjetlo obavijesti';

  @override
  String get ledNotificationsDescription =>
      'Pali bljeskalicu za podsjetnike. Dostupno samo na uređajima s LED svjetlosnim obavijestima.';

  @override
  String get repairDatabase => 'Popravi bazu podataka';

  @override
  String get databaseRepaired => 'Baza podataka je popravljena.';

  @override
  String get uncheck => 'Odznači';

  @override
  String get toggle => 'Uključi/isključi';

  @override
  String get action => 'Radnja';

  @override
  String get habit => 'Navika';

  @override
  String get sort => 'Sortiraj';

  @override
  String get manually => 'Ručno';

  @override
  String get byName => 'Po nazivu';

  @override
  String get byColor => 'Po boji';

  @override
  String get byScore => 'Po rezultatu';

  @override
  String get byStatus => 'Po statusu';

  @override
  String get export => 'Izvezi';

  @override
  String get longPressToEdit => 'Pritisni i zadrži za promjenu vrijednosti';

  @override
  String get value => 'Vrijednost';

  @override
  String get calendar => 'Kalendar';

  @override
  String get unit => 'Jedinica';

  @override
  String get targetType => 'Vrsta cilja';

  @override
  String get targetTypeAtLeast => 'Najmanje';

  @override
  String get targetTypeAtMost => 'Najviše';

  @override
  String get exampleQuestionBoolean => 'npr. Jesi li vježbao/la danas?';

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
      'Postavi zvuk, vibraciju, svjetlo i druge postavke obavijesti';

  @override
  String get customizeNotification => 'Prilagodi obavijesti';

  @override
  String get prefViewPrivacy => 'Prikaži pravila o privatnosti';

  @override
  String get viewAllContributors => 'Pregledaj sve suradnike…';

  @override
  String get database => 'Baza podataka';

  @override
  String get widgetOpacityTitle => 'Prozirnost widgeta';

  @override
  String get widgetOpacityDescription =>
      'Povećava ili smanjuje prozirnost widgeta na početnom zaslonu.';

  @override
  String get firstDayOfTheWeek => 'Prvi dan u tjednu';

  @override
  String get defaultReminderQuestion => 'Jesi li ispunio/la ovu naviku danas?';

  @override
  String get notes => 'Bilješke';

  @override
  String get exampleNotes => '(Neobvezno)';

  @override
  String get yesOrNoExample =>
      'npr. Jesi li se danas rano probudio/la? Jesi li vježbao/la? Jesi li igrao/la šah?';

  @override
  String get measurable => 'Mjerljivo';

  @override
  String get measurableExample =>
      'npr. Koliko si kilometara danas istrčao/la? Koliko si stranica pročitao/la?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 puta tjedno';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 puta mjesečno';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 puta u $p2 dani';
  }

  @override
  String get yesOrNoShortExample => 'npr. Vježbaj';

  @override
  String get color => 'Boja';

  @override
  String get exampleTarget => 'npr. 15';

  @override
  String get measurableShortExample => 'npr. Trči';

  @override
  String get measurableQuestionExample =>
      'npr. Koliko si kilometara danas trčao/la?';

  @override
  String get measurableUnitsExample => 'npr. kilometri';

  @override
  String get everyMonth => 'Svaki mjesec';

  @override
  String get validationCannotBeBlank => 'Ne može ostati prazno';

  @override
  String get today => 'Danas';

  @override
  String get enter => 'Unesi';

  @override
  String get noHabits => 'Navike nisu pronađene';

  @override
  String get noNumericalHabits => 'Mjerljive navike nisu pronađene';

  @override
  String get noBooleanHabits => 'Da/Ne navike nisu pronađene';

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
      other: 'Navike su izbrisane',
      few: 'Navike su izbrisane',
      one: 'Navika je obrisana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike su arhivirane',
      few: 'Navike su arhivirane',
      one: 'Navika je arhivirana',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Navike su dearhivirane',
      few: 'Navike su dearhivirane',
      one: 'Navika je dearhivitana',
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
}
