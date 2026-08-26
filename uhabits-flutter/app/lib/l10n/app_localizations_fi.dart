// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class L10nFi extends L10n {
  L10nFi([String locale = 'fi']) : super(locale);

  @override
  String get overview => 'Yleiskatsaus';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Rutiinit';

  @override
  String get actionSettings => 'Asetukset';

  @override
  String get edit => 'Muokkaa';

  @override
  String get delete => 'Poista';

  @override
  String get archive => 'Arkistoi';

  @override
  String get unarchive => 'Kumoa arkistointi';

  @override
  String get addHabit => 'Lisää rutiini';

  @override
  String get colorPickerDefaultTitle => 'Vaihda väriä';

  @override
  String get toastHabitCreated => 'Rutiini luotu';

  @override
  String get habitStrength => 'Rutiinin vahvuus';

  @override
  String get history => 'Historia';

  @override
  String get clear => 'Tyhjennä';

  @override
  String get reminder => 'Muistutus';

  @override
  String get save => 'Tallenna';

  @override
  String get streaks => 'Pisimmät toistot';

  @override
  String get noHabitsFound => 'Ei aktiivisia rutiineja';

  @override
  String get noHabitsLeftToDo => 'Olet tältä päivältä valmis!';

  @override
  String get longPressToToggle =>
      'Paina pitkään merkitäksesi suoritetuksi tai poistaaksesi suorituksen';

  @override
  String get reminderOff => 'Pois päältä';

  @override
  String get createHabit => 'Luo rutiini';

  @override
  String get editHabit => 'Muokkaa rutiinia';

  @override
  String get check => 'Merkitse tehdyksi';

  @override
  String get snooze => 'Lykkää';

  @override
  String get introTitle1 => 'Tervetuloa';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker auttaa sinua luomaan ja ylläpitämään hyviä rutiineja.';

  @override
  String get introTitle2 => 'Merkitse uusia rutiineja';

  @override
  String get introDescription2 =>
      'Joka päivä, suoritettuasi rutiinin, merkitse se sovellukseen.';

  @override
  String get introTitle4 => 'Seuraa kehitystäsi';

  @override
  String get introDescription4 =>
      'Yksityiskohtaiset kaaviot näyttävät, kuinka rutiinisi ovat kehittyneet ajan kuluessa.';

  @override
  String get interval15Minutes => '15 minuuttia';

  @override
  String get interval30Minutes => '30 minuuttia';

  @override
  String get interval1Hour => '1 tunti';

  @override
  String get interval2Hour => '2 tuntia';

  @override
  String get interval4Hour => '4 tuntia';

  @override
  String get interval8Hour => '8 tuntia';

  @override
  String get interval24Hour => '24 tuntia';

  @override
  String get intervalAlwaysAsk => 'Kysy aina';

  @override
  String get intervalCustom => 'Muu';

  @override
  String get prefToggleTitle => 'Vaihda merkintää lyhyellä painalluksella';

  @override
  String get prefToggleDescription2 =>
      'Lisää valinnat yhdellä napautuksella pitkään painettuna pitämisen sijaan.';

  @override
  String get prefRateThisApp => 'Arvostele Google Playssä';

  @override
  String get prefSendFeedback => 'Lähetä palautetta kehittäjälle';

  @override
  String get prefViewSourceCode => 'Katso lähdekoodi GitHubissa';

  @override
  String get links => 'Linkit';

  @override
  String get name => 'Nimi';

  @override
  String get settings => 'Asetukset';

  @override
  String get selectSnoozeDelay => 'Aseta torkkuaika';

  @override
  String get hintTitle => 'Tiesitkö?';

  @override
  String get hintDrag =>
      'Muokkaa merkintöjen järjestystä: valitse tavan nimi ja vedä se oikeaan paikkaan.';

  @override
  String get hintLandscape =>
      'Näe lisää päiviä kääntämällä puhelimesi pitkittäin.';

  @override
  String get habitNotFound => 'Tapa on poistettu tai sitä ei löydy';

  @override
  String get weekends => 'Viikonloppuisin';

  @override
  String get anyWeekday => 'Maanantaista perjantaihin';

  @override
  String get anyDay => 'Mikä tahansa viikonpäivä';

  @override
  String get selectWeekdays => 'Valitse päivät';

  @override
  String get exportToCsv => 'Vie CSV-muodossa';

  @override
  String get doneLabel => 'Valmis';

  @override
  String get clearLabel => 'Tyhjennä';

  @override
  String get selectHours => 'Valitse tunnit';

  @override
  String get selectMinutes => 'Valitse minuutit';

  @override
  String get about => 'Tietoa sovelluksesta';

  @override
  String get translators => 'Kääntäjät';

  @override
  String get developers => 'Kehittäjät';

  @override
  String versionN(String p1) {
    return 'Versio $p1';
  }

  @override
  String get frequency => 'Toistuvuus';

  @override
  String get checkmark => 'Valintamerkki';

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
  String get bestStreaks => 'Parhaat putket';

  @override
  String get everyDay => 'Joka päivä';

  @override
  String get everyWeek => 'Joka viikko';

  @override
  String get help => 'Ohjeita ja usein kysyttyä';

  @override
  String get couldNotExport => 'Tietojen vienti ei onnistunut.';

  @override
  String get couldNotImport => 'Tietojen tuominen ei onnistunut.';

  @override
  String get fileNotRecognized => 'Tiedostoa ei tunnistettu.';

  @override
  String get habitsImported => 'Rutiinit tuotu onnistuneesti.';

  @override
  String get importData => 'Tuo tiedot';

  @override
  String get exportFullBackup => 'Vie täysi varmuuskopio';

  @override
  String get importDataSummary =>
      'Tukee tästä sovelluksesta vietyjä täysiä varmuuskopioita, sekä tiedostoja jotka on luotu sovelluksissa Tickmate, HabitBull ja Rewire. Katso usein kysytyistä kysymyksistä lisätietoa.';

  @override
  String get exportAsCsvSummary =>
      'Luo tiedostoja jotka voidaan avata taulukkolaskentaohjelmistolla, kuten Microsoft Excel tai OpenOffice Calc. Tätä tiedostoa ei voi tuoda takaisin.';

  @override
  String get exportFullBackupSummary =>
      'Luo tiedoston jossa on kaikki tietosi. Tämä tiedosto voidaan tuoda takaisin.';

  @override
  String get selectPublicBackupFolder => 'Valitse julkinen varmuuskopiokansio';

  @override
  String get noPublicBackupFolderSelected => 'Kansiota ei valittu';

  @override
  String get bugReportFailed => 'Virheraportin luonti epäonnistui.';

  @override
  String get generateBugReport => 'Luo virheraportti';

  @override
  String get troubleshooting => 'Apua';

  @override
  String get helpTranslate => 'Auta kääntämään tämä sovellus';

  @override
  String get nightMode => 'Yötila';

  @override
  String get usePureBlack => 'Käytä puhdasta mustaa yötilassa';

  @override
  String get pureBlackDescription =>
      'Korvaa harmaat taustat puhtaalla mustalla tummalla teemalla. Vähentää akun käyttöä puhelimissa AMOLED-näytöllä.';

  @override
  String get interfacePreferences => 'Käyttöliittymä';

  @override
  String get reverseDays => 'Päivät käänteisessä järjestyksessä';

  @override
  String get reverseDaysDescription =>
      'Näytä päivät käänteisessä järjestyksessä päänäytöllä.';

  @override
  String get day => 'Päivä';

  @override
  String get week => 'Viikko';

  @override
  String get month => 'Kuukausi';

  @override
  String get quarter => 'Kvartaali';

  @override
  String get year => 'Vuosi';

  @override
  String get total => 'Yhteensä';

  @override
  String get yesOrNo => 'Kyllä vai ei?';

  @override
  String everyXDays(int p1) {
    return '$p1 päivän välein';
  }

  @override
  String everyXWeeks(int p1) {
    return '$p1 viikon välein';
  }

  @override
  String get score => 'Pisteet';

  @override
  String get reminderSound => 'Muistutusääni';

  @override
  String get none => 'Ei mitään';

  @override
  String get filter => 'Suodata';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Piilota suoritetut';

  @override
  String get hideEntered => 'Piilota syötetty';

  @override
  String get hideArchived => 'Piilota arkistoidut';

  @override
  String get stickyNotifications => 'Tee ilmoituksesta kiinnitettyjä';

  @override
  String get stickyNotificationsDescription =>
      'Estää ilmoitusten pois pyyhkäisemisen.';

  @override
  String get ledNotifications => 'Ilmoitusvalo';

  @override
  String get ledNotificationsDescription =>
      'Näyttää vilkkuvan valon ilmoituksista. Vain puhelimissa joissa on LED-ilmoitusvalo.';

  @override
  String get repairDatabase => 'Korjaa tietokanta';

  @override
  String get databaseRepaired => 'Tietokanta korjattu.';

  @override
  String get uncheck => 'Poista tehdyksi merkintä';

  @override
  String get toggle => 'Tilanvaihto';

  @override
  String get action => 'Toiminta';

  @override
  String get habit => 'Rutiini';

  @override
  String get sort => 'Järjestä';

  @override
  String get manually => 'Käsin';

  @override
  String get byName => 'Nimen mukaan';

  @override
  String get byColor => 'Värin mukaan';

  @override
  String get byScore => 'Pisteiden mukaan';

  @override
  String get byStatus => 'Tilan mukaan';

  @override
  String get export => 'Vie';

  @override
  String get longPressToEdit => 'Pidä painettuna muuttaaksesi arvoa';

  @override
  String get value => 'Arvo';

  @override
  String get calendar => 'Kalenteri';

  @override
  String get unit => 'Yksikkö';

  @override
  String get targetType => 'Kohdetyyppi';

  @override
  String get targetTypeAtLeast => 'Vähintään';

  @override
  String get targetTypeAtMost => 'Enintään';

  @override
  String get exampleQuestionBoolean => 'esim. Harrastitko tänään liikuntaa?';

  @override
  String get question => 'Kysymys';

  @override
  String get target => 'Tavoite';

  @override
  String get yes => 'Kyllä';

  @override
  String get no => 'Ei';

  @override
  String get customizeNotificationSummary =>
      'Muuta ilmoitusten ääntä, värinää, valoa ja muita asetuksia';

  @override
  String get customizeNotification => 'Mukauta ilmoituksia';

  @override
  String get prefViewPrivacy => 'Katso tietosuojakäytäntö';

  @override
  String get viewAllContributors => 'Näytä kaikki osallistujat…';

  @override
  String get database => 'Tietokanta';

  @override
  String get widgetOpacityTitle => 'Widgetin läpinäkyvyys';

  @override
  String get widgetOpacityDescription =>
      'Muuttaa kotinäkymän widgettien läpinäkyvyyttä.';

  @override
  String get firstDayOfTheWeek => 'Viikon ensimmäinen päivä';

  @override
  String get defaultReminderQuestion =>
      'Oletko suorittanut tämän tavan tänään?';

  @override
  String get notes => 'Muistiinpanot';

  @override
  String get exampleNotes => '(Valinnainen)';

  @override
  String get yesOrNoExample =>
      'Esim. heräsitkö tänään aikaisin? Kuntoilitko? Pelasitko sakkia?';

  @override
  String get measurable => 'Mitattava';

  @override
  String get measurableExample =>
      'esim. Montako kilometriä juoksit tänään? Montako sivua luit?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 kertaa viikossa';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 kertaa kuukaudessa';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 kertaa $p2 päivässä';
  }

  @override
  String get yesOrNoShortExample => 'Esim. kuntoilu';

  @override
  String get color => 'Väri';

  @override
  String get exampleTarget => 'Esim. 15';

  @override
  String get measurableShortExample => 'Esim. juokse';

  @override
  String get measurableQuestionExample =>
      'Esim. kuinka monta kilometriä juoksit tänään?';

  @override
  String get measurableUnitsExample => 'Esim. kilometriä';

  @override
  String get everyMonth => 'Joka kuukausi';

  @override
  String get validationCannotBeBlank => 'Tätä ei voi jättää tyhjäksi';

  @override
  String get today => 'Tänään';

  @override
  String get enter => 'Syötä';

  @override
  String get noHabits => 'Rutiineja ei löydetty';

  @override
  String get noNumericalHabits => 'Mitattavia rutiineja ei löytynyt';

  @override
  String get noBooleanHabits => 'Kyllä-tai-ei-rutiineja ei löytynyt';

  @override
  String get increment => 'Nosta';

  @override
  String get decrement => 'Laske';

  @override
  String get prefSkipTitle => 'Ota ohituspäivät käyttöön';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Valitse kahdesti lisätäksesi ohituksen valinnan sijaan. Ohitukset pitävät pisteesi muuttumattomana eivätkä riko suoritusputkeasi.';

  @override
  String get prefUnknownTitle =>
      'Näytä kysymysmerkki puuttuvan tiedon kohdalla';

  @override
  String get prefUnknownDescription =>
      'Erota päivät ilman tietoja todellisista väliin jäämisistä. Lisätäksesi väliin jäämisen, valitse kahdesti.';

  @override
  String get youAreNowADeveloper => 'Olet nyt kehittäjä';

  @override
  String get activityNotFound =>
      'Tälle toiminnolle ei löytynyt yhtään sovellusta';

  @override
  String get prefMidnightDelayTitle =>
      'Pidennä päivää muutama tunti keskiyön jälkeen';

  @override
  String get prefMidnightDelayDescription =>
      'Odota kello 3.00 asti ennen uuden päivän näyttämistä. Hyödyllinen jos menet nukkumaan yleensä keskiyön jälkeen. Vaatii sovelluksen uudelleenkäynnistyksen.';

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
      other: 'Rutiinit muutettu',
      one: 'Rutiini muutettu',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rutiinit poistettu',
      one: 'Rutiini poistettu',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rutiinit arkistoitu',
      one: 'Rutiini arkistoitu',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rutiinit palautettu arkistosta',
      one: 'Rutiini palautettu arkistosta',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Poista rutiinit?',
      one: 'Poista rutiini?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rutiinit poistetaan pysyvästi. Toimintoa ei voi peruuttaa.',
      one: 'Rutiini poistetaan pysyvästi. Toimintoa ei voi peruuttaa.',
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
}
