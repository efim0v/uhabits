// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovak (`sk`).
class L10nSk extends L10n {
  L10nSk([String locale = 'sk']) : super(locale);

  @override
  String get overview => 'Prehľad';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Návyky';

  @override
  String get actionSettings => 'Nastavenia';

  @override
  String get edit => 'Upraviť';

  @override
  String get delete => 'Vymazať';

  @override
  String get archive => 'Archivovať';

  @override
  String get unarchive => 'Odarchivovať';

  @override
  String get addHabit => 'Pridaj návyk';

  @override
  String get colorPickerDefaultTitle => 'Zmeniť farbu';

  @override
  String get toastHabitCreated => 'Návyk vytvorený';

  @override
  String get habitStrength => 'Sila návyku';

  @override
  String get history => 'História';

  @override
  String get clear => 'Zmazať';

  @override
  String get reminder => 'Pripomienka';

  @override
  String get save => 'Uložiť';

  @override
  String get streaks => 'Série';

  @override
  String get noHabitsFound => 'Nemáte žiadne aktívne návyky';

  @override
  String get noHabitsLeftToDo => 'Na dnes máte všetko hotové!';

  @override
  String get longPressToToggle =>
      'Stlačením a podržaním začiarknite alebo zrušte začiarknutie políčka';

  @override
  String get reminderOff => 'Vypnuté';

  @override
  String get createHabit => 'Vytvoriť návyk';

  @override
  String get editHabit => 'Upraviť návyk';

  @override
  String get check => 'Začiarknuť';

  @override
  String get snooze => 'Neskôr';

  @override
  String get introTitle1 => 'Vitajte';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker vám pomáha vytvárať a udržiavať dobré návyky.';

  @override
  String get introTitle2 => 'Vytvorte nejaké nové návyky';

  @override
  String get introDescription2 =>
      'Každý deň po vykonaní návyku pridajte začiarknutie v aplikácii.';

  @override
  String get introTitle4 => 'Sledujte svoj pokrok';

  @override
  String get introDescription4 =>
      'Podrobné grafy ukazujú, ako sa vaše návyky postupom času zlepšovali.';

  @override
  String get interval15Minutes => '15 minút';

  @override
  String get interval30Minutes => '30 minút';

  @override
  String get interval1Hour => '1 hodina';

  @override
  String get interval2Hour => '2 hodiny';

  @override
  String get interval4Hour => '4 hodiny';

  @override
  String get interval8Hour => '8 hodín';

  @override
  String get interval24Hour => '24 hodín';

  @override
  String get intervalAlwaysAsk => 'Vždy sa spýtať';

  @override
  String get intervalCustom => 'Vlastné ...';

  @override
  String get prefToggleTitle => 'Prepnúť krátkym stlačením';

  @override
  String get prefToggleDescription2 =>
      'Začiarknite jediným klepnutím namiesto stlačenia a podržania.';

  @override
  String get prefRateThisApp => 'Ohodnoťte túto aplikáciu na Google Play';

  @override
  String get prefSendFeedback => 'Odošlite spätnú väzbu vývojárovi';

  @override
  String get prefViewSourceCode => 'Zobraziť zdrojový kód na stránke GitHub';

  @override
  String get links => 'Odkazy';

  @override
  String get name => 'Názov';

  @override
  String get settings => 'Nastavenia';

  @override
  String get selectSnoozeDelay => 'Nastaviť dĺžku odloženia';

  @override
  String get hintTitle => 'Vedeli ste?';

  @override
  String get hintDrag =>
      'Pre zmenu usporiadania záznamov, stlačte a podržte názov návyku a potom ho presuňte na správne miesto.';

  @override
  String get hintLandscape =>
      'Môžete vidieť viac dní otočením telefónu do režimu na šírku.';

  @override
  String get habitNotFound => 'Návyk bol odstránený / nenájdený';

  @override
  String get weekends => 'Víkendy';

  @override
  String get anyWeekday => 'Od pondelka do piatku';

  @override
  String get anyDay => 'Každý deň v týždni';

  @override
  String get selectWeekdays => 'Vyberte dni';

  @override
  String get exportToCsv => 'Exportovať ako CSV';

  @override
  String get doneLabel => 'Hotovo';

  @override
  String get clearLabel => 'Zmazať';

  @override
  String get selectHours => 'Vyberte hodiny';

  @override
  String get selectMinutes => 'Vyberte minúty';

  @override
  String get about => 'O aplikácii';

  @override
  String get translators => 'Prekladatelia';

  @override
  String get developers => 'Vývojári';

  @override
  String versionN(String p1) {
    return 'Verzia $p1';
  }

  @override
  String get frequency => 'Frekvencia';

  @override
  String get checkmark => 'Začiarknutie';

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
  String get bestStreaks => 'Najlepšie série';

  @override
  String get everyDay => 'Každý deň';

  @override
  String get everyWeek => 'Každý týždeň';

  @override
  String get help => 'Pomoc & FAQ';

  @override
  String get couldNotExport => 'Export údajov zlyhal.';

  @override
  String get couldNotImport => 'Import údajov zlyhal.';

  @override
  String get fileNotRecognized => 'Súbor nebol rozpoznaný.';

  @override
  String get habitsImported => 'Návyky boli úspešne importované.';

  @override
  String get importData => 'Import údajov';

  @override
  String get exportFullBackup => 'Exportovať celú zálohu';

  @override
  String get importDataSummary =>
      'Podporuje úplné zálohy exportované touto aplikáciou, ako aj súbory generované aplikáciami Tickmate, HabitBull alebo Rewire. Viac informácií nájdete v častých otázkach (FAQ).';

  @override
  String get exportAsCsvSummary =>
      'Generuje súbory, ktoré je možné otvoriť pomocou tabuľkového softvéru, ako je Microsoft Excel alebo OpenOffice Calc. Tento súbor nie je možné importovať späť.';

  @override
  String get exportFullBackupSummary =>
      'Vytvorí súbor, ktorý obsahuje všetky vaše údaje. Tento súbor je možné importovať späť.';

  @override
  String get selectPublicBackupFolder => 'Vybrať verejný priečinok zálohy';

  @override
  String get noPublicBackupFolderSelected => 'Nie je vybratý žiadny priečinok';

  @override
  String get bugReportFailed => 'Vygenerovanie hlásenia o chybe zlyhalo.';

  @override
  String get generateBugReport => 'Vygenerujte hlásenie o chybe';

  @override
  String get troubleshooting => 'Riešenie problémov';

  @override
  String get helpTranslate => 'Pomôžte preložiť túto aplikáciu';

  @override
  String get nightMode => 'Tmavá téma';

  @override
  String get usePureBlack => 'Použite čisto čiernu farbu v tmavej téme';

  @override
  String get pureBlackDescription =>
      'Nahrádza sivé pozadie čisto čiernym v tmavej téme. Znižuje spotrebu batérie v telefónoch s displejom AMOLED.';

  @override
  String get interfacePreferences => 'Rozhranie';

  @override
  String get reverseDays => 'Opačné poradie dní';

  @override
  String get reverseDaysDescription =>
      'Zobraziť dni v opačnom poradí na hlavnej obrazovke.';

  @override
  String get day => 'Deň';

  @override
  String get week => 'Týždeň';

  @override
  String get month => 'Mesiac';

  @override
  String get quarter => 'Štvrťrok';

  @override
  String get year => 'Rok';

  @override
  String get total => 'Celkom';

  @override
  String get yesOrNo => 'Áno alebo Nie';

  @override
  String everyXDays(int p1) {
    return 'Každých $p1 dní';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Každých $p1 týždňov';
  }

  @override
  String get score => 'Skóre';

  @override
  String get reminderSound => 'Zvuk pripomienky';

  @override
  String get none => 'Žiadny';

  @override
  String get filter => 'Filter';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Skryť dokončené';

  @override
  String get hideEntered => 'Skryť vyplnené';

  @override
  String get hideArchived => 'Skryť archivované';

  @override
  String get stickyNotifications => 'Pripnúť oznámenia';

  @override
  String get stickyNotificationsDescription =>
      'Zabráni odstráneniu notifikácií odsunutím.';

  @override
  String get ledNotifications => 'LED signalizácia upozornení';

  @override
  String get ledNotificationsDescription =>
      'Zobrazuje blikajúce svetlo pre pripomenutia. K dispozícii iba v telefónoch s kontrolkami LED.';

  @override
  String get repairDatabase => 'Opraviť databázu';

  @override
  String get databaseRepaired => 'Databáza bola opravená.';

  @override
  String get uncheck => 'Odznačiť';

  @override
  String get toggle => 'Prepnúť';

  @override
  String get action => 'Akcia';

  @override
  String get habit => 'Návyk';

  @override
  String get sort => 'Zoradiť';

  @override
  String get manually => 'Ručne';

  @override
  String get byName => 'Podľa názvu';

  @override
  String get byColor => 'Podľa farby';

  @override
  String get byScore => 'Podľa skóre';

  @override
  String get byStatus => 'Podľa stavu';

  @override
  String get export => 'Exportovať';

  @override
  String get longPressToEdit => 'Stlačením a podržaním zmeníte hodnotu';

  @override
  String get value => 'Hodnota';

  @override
  String get calendar => 'Kalendár';

  @override
  String get unit => 'Jednotka';

  @override
  String get targetType => 'Typ cieľa:';

  @override
  String get targetTypeAtLeast => 'Aspoň';

  @override
  String get targetTypeAtMost => 'Najviac';

  @override
  String get exampleQuestionBoolean => 'napr. Cvičili ste dnes?';

  @override
  String get question => 'Otázka';

  @override
  String get target => 'Cieľ';

  @override
  String get yes => 'Áno';

  @override
  String get no => 'Nie';

  @override
  String get customizeNotificationSummary =>
      'Zmeňte nastavenie zvuku, vibrácií, svetla a ďalších nastavení upozornení';

  @override
  String get customizeNotification => 'Prispôsobiť oznámenia';

  @override
  String get prefViewPrivacy => 'Zobraziť zásady ochrany osobných údajov';

  @override
  String get viewAllContributors => 'Zobraziť všetkých prispievateľov…';

  @override
  String get database => 'Databáza';

  @override
  String get widgetOpacityTitle => 'Nepriehľadnosť widgetu';

  @override
  String get widgetOpacityDescription =>
      'Zvyšuje priehľadnosť alebo nepriehľadnosť widgetov na vašej domovskej obrazovke.';

  @override
  String get firstDayOfTheWeek => 'Prvý deň v týždni';

  @override
  String get defaultReminderQuestion => 'Už ste tento zvyk dokončili dnes?';

  @override
  String get notes => 'Poznámky';

  @override
  String get exampleNotes => '(voliteľné)';

  @override
  String get yesOrNoExample =>
      'napr. Zobudili ste sa dnes skoro? Cvičili ste? Hrali ste šach?';

  @override
  String get measurable => 'Merateľné';

  @override
  String get measurableExample =>
      'napr. Koľko kilometrov ste dnes nabehali? Koľko strán ste prečítali?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 krát týždenne';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 krát za mesiac';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 krát za $p2 dní';
  }

  @override
  String get yesOrNoShortExample => 'napr. Cvičenie';

  @override
  String get color => 'Farba';

  @override
  String get exampleTarget => 'napr. 15';

  @override
  String get measurableShortExample => 'napr. Beh';

  @override
  String get measurableQuestionExample =>
      'napr. Koľko kilometrov ste dnes prešli?';

  @override
  String get measurableUnitsExample => 'napr. kilometre';

  @override
  String get everyMonth => 'Každý mesiac';

  @override
  String get validationCannotBeBlank => 'Nemôže byť prázdne';

  @override
  String get today => 'Dnes';

  @override
  String get enter => 'Zadať';

  @override
  String get noHabits => 'Nenašli sa žiadne návyky';

  @override
  String get noNumericalHabits => 'Nenašli sa žiadne merateľné návyky';

  @override
  String get noBooleanHabits => 'Nenašli sa žiadne áno-alebo-nie návyky';

  @override
  String get increment => 'Navýšiť';

  @override
  String get decrement => 'Znížiť';

  @override
  String get prefSkipTitle => 'Povoliť preskočenie dní';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Dvojitým prepnutím pridáte namiesto začiarknutia preskočenie. Preskočenia udržia vaše skóre nezmenené a neprerušia vašu sériu.';

  @override
  String get prefUnknownTitle => 'Zobraziť otázniky pre chýbajúce údaje';

  @override
  String get prefUnknownDescription =>
      'Odlíšte dni bez údajov od skutočných prerušení. Ak chcete zadať prerušenie, dvakrát prepnite.';

  @override
  String get youAreNowADeveloper => 'Teraz ste vývojár';

  @override
  String get activityNotFound =>
      'Nenašla sa žiadna aplikácia podporujúca túto akciu';

  @override
  String get prefMidnightDelayTitle =>
      'Predĺžte deň o niekoľko hodín po polnoci';

  @override
  String get prefMidnightDelayDescription =>
      'Na zobrazenie nového dňa počkajte do 3:00. Užitočné, ak zvyčajne chodíte spať po polnoci. Vyžaduje reštart aplikácie.';

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
      other: 'Návykov zmenených',
      many: 'Návykov zmenených',
      few: 'Návyky zmenené',
      one: 'Návyk zmenený',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návykov zmazaných',
      many: 'Návykov zmazaných',
      few: 'Návyky zmazané',
      one: 'Návyk zmazaný',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návykov dosiahnutých',
      many: 'Návykov dosiahnutých',
      few: 'Návyky dosiahnuté',
      one: 'Návyk dosiahnutý',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návykov nedosiahnutých',
      many: 'Návykov nedosiahnutých',
      few: 'Návyky nedosiahnuté',
      one: 'Návyk nedosiahnutý',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odstrániť návyky?',
      many: 'Odstrániť návyky?',
      few: 'Odstrániť návyky?',
      one: 'Odstrániť návyk?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Návyky budú natrvalo odstránené. Tento krok nie je možné vrátiť späť.',
      many:
          'Návyky budú natrvalo odstránené. Tento krok nie je možné vrátiť späť.',
      few:
          'Návyky budú natrvalo odstránené. Tento krok nie je možné vrátiť späť.',
      one:
          'Návyk bude natrvalo odstránený. Tento krok nie je možné vrátiť späť.',
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
