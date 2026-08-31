// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class L10nCs extends L10n {
  L10nCs([String locale = 'cs']) : super(locale);

  @override
  String get overview => 'Přehled';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Zvyky';

  @override
  String get actionSettings => 'Nastavení';

  @override
  String get edit => 'Upravit';

  @override
  String get delete => 'Smazat';

  @override
  String get archive => 'Archivovat';

  @override
  String get unarchive => 'Obnovit';

  @override
  String get addHabit => 'Přidat zvyk';

  @override
  String get colorPickerDefaultTitle => 'Změnit barvu';

  @override
  String get toastHabitCreated => 'Zvyk vytvořen.';

  @override
  String get habitStrength => 'Síla zvyku';

  @override
  String get history => 'Historie';

  @override
  String get clear => 'Smazat';

  @override
  String get reminder => 'Připomenutí';

  @override
  String get save => 'Uložit';

  @override
  String get streaks => 'Série';

  @override
  String get noHabitsFound => 'Nemáte žádné aktivní návyky';

  @override
  String get noHabitsLeftToDo => 'Dnes máte hotovo!';

  @override
  String get longPressToToggle => 'Stiskni a drž pro označení';

  @override
  String get reminderOff => 'Vyp.';

  @override
  String get createHabit => 'Vytvořit zvyk';

  @override
  String get editHabit => 'Upravit zvyk';

  @override
  String get check => 'Hotovo';

  @override
  String get snooze => 'Odložit';

  @override
  String get introTitle1 => 'Vítejte';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker vám pomůže vytvořit a udržet dobré návyky.';

  @override
  String get introTitle2 => 'Vytvoř si nové zvyky';

  @override
  String get introDescription2 =>
      'Každý den po splnění zvyku si ho v aplikaci zaškrtněte.';

  @override
  String get introTitle4 => 'Sleduj svůj postup';

  @override
  String get introDescription4 =>
      'Detailní grafy ukazují zlepšení vašich návyků v průběhu času.';

  @override
  String get interval15Minutes => '15 minut';

  @override
  String get interval30Minutes => '30 minut';

  @override
  String get interval1Hour => '1 hodina';

  @override
  String get interval2Hour => '2 hodiny';

  @override
  String get interval4Hour => '4 hodiny';

  @override
  String get interval8Hour => '8 hodin';

  @override
  String get interval24Hour => '24 hodin';

  @override
  String get intervalAlwaysAsk => 'Vždy se dotázat';

  @override
  String get intervalCustom => 'Vlastní...';

  @override
  String get prefToggleTitle => 'Označte krátkým stisknutím';

  @override
  String get prefToggleDescription2 =>
      'Zaškrtněte jediným klepnutím namísto dlouhého podržení.';

  @override
  String get prefRateThisApp => 'Ohodnotit aplikaci v Google Play';

  @override
  String get prefSendFeedback => 'Odeslat zpětnou vazbu vývojáři';

  @override
  String get prefViewSourceCode => 'Zobrazit zdrojový kód na GitHub';

  @override
  String get links => 'Odkazy';

  @override
  String get name => 'Název';

  @override
  String get settings => 'Nastavení';

  @override
  String get selectSnoozeDelay => 'Nastavit délku odložení';

  @override
  String get hintTitle => 'Věděli jste?';

  @override
  String get hintDrag =>
      'Pro přeřazení položek stiskněte a podržte název zvyku a přesuňte ho na správné místo.';

  @override
  String get hintLandscape =>
      'Můžete vidět více dnů otočením telefonu na šířku.';

  @override
  String get habitNotFound => 'Zvyk smazán / nenalezen';

  @override
  String get weekends => 'Víkendy';

  @override
  String get anyWeekday => 'Pondělí až pátek';

  @override
  String get anyDay => 'Jakýkoliv den v týdnu';

  @override
  String get selectWeekdays => 'Vyberte dny';

  @override
  String get exportToCsv => 'Exportovat CSV';

  @override
  String get doneLabel => 'Hotovo';

  @override
  String get clearLabel => 'Smazat';

  @override
  String get selectHours => 'Vyberte hodiny';

  @override
  String get selectMinutes => 'Vyberte minuty';

  @override
  String get about => 'O nás';

  @override
  String get translators => 'Překladatelé';

  @override
  String get developers => 'Vývojáři';

  @override
  String versionN(String p1) {
    return 'Verze $p1';
  }

  @override
  String get frequency => 'Frekvence';

  @override
  String get checkmark => 'Zaškrtnutí';

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
  String get bestStreaks => 'Nejlepší série';

  @override
  String get everyDay => 'Každý den';

  @override
  String get everyWeek => 'Každý týden';

  @override
  String get help => 'Pomoc a FAQ';

  @override
  String get couldNotExport => 'Export selhal.';

  @override
  String get couldNotImport => 'Import selhal.';

  @override
  String get fileNotRecognized => 'Soubor nerozpoznán.';

  @override
  String get habitsImported => 'Zvyky úspěšně importovány.';

  @override
  String get importData => 'Importovat';

  @override
  String get exportFullBackup => 'Kompletní export';

  @override
  String get importDataSummary =>
      'Podporuje plné zálohy z této aplikace, stejně jako soubory vygenerované aplikacemi od Tickmate, HabitBull nebo Rewire. Pro více informací konzultujte FAQ.';

  @override
  String get exportAsCsvSummary =>
      'Generuje soubory, které mohou být otevřeny v tabulkových editorech jako jsou Microsoft Excel nebo OpenOffice Calc. Tento soubor nelze importovat zpět.';

  @override
  String get exportFullBackupSummary =>
      'Generuje soubor, který obsahuje veškerá vaše data. Tento soubor může být importován zpět.';

  @override
  String get selectPublicBackupFolder => 'Vyberte veřejnou složku zálohy';

  @override
  String get noPublicBackupFolderSelected => 'Nebyla vybrána žádná složka';

  @override
  String get bugReportFailed => 'Generace výpisu chyb selhala.';

  @override
  String get generateBugReport => 'Generovat výpis chyb';

  @override
  String get troubleshooting => 'Řešení problémů';

  @override
  String get helpTranslate => 'Pomozte s překladem aplikace';

  @override
  String get nightMode => 'Temný motiv';

  @override
  String get usePureBlack => 'Zobrazit čistě černou v temném motivu';

  @override
  String get pureBlackDescription =>
      'Nahrazuje v temném motivu šedé pozadí čistou černou. Snižuje spotřebu baterie v telefonech s AMOLED displejem.';

  @override
  String get interfacePreferences => 'Rozhraní';

  @override
  String get reverseDays => 'Otočit pořadí dnů';

  @override
  String get reverseDaysDescription =>
      'Zobrazit dny na úvodní stránce v obráceném pořadí.';

  @override
  String get day => 'Den';

  @override
  String get week => 'Týden';

  @override
  String get month => 'Měsíc';

  @override
  String get quarter => 'Čtvrtletí';

  @override
  String get year => 'Rok';

  @override
  String get total => 'Celkem';

  @override
  String get yesOrNo => 'Ano nebo Ne';

  @override
  String everyXDays(int p1) {
    return 'Každých $p1 dní';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Každých $p1 týdnů';
  }

  @override
  String get score => 'Skóre';

  @override
  String get reminderSound => 'Zvuk upozornění';

  @override
  String get none => 'Žádný';

  @override
  String get filter => 'Filtr';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Skrýt dokončené';

  @override
  String get hideEntered => 'Skrýt vyplněné';

  @override
  String get hideArchived => 'Skrýt archivované';

  @override
  String get stickyNotifications => 'Připnout upozornění';

  @override
  String get stickyNotificationsDescription =>
      'Zabraňuje odstranění upozornění přejetím.';

  @override
  String get ledNotifications => 'Světelné upozornění';

  @override
  String get ledNotificationsDescription =>
      'Bliká při upozornění. Pouze pro telefony s LED notifikačními světly.';

  @override
  String get repairDatabase => 'Opravit databázi';

  @override
  String get databaseRepaired => 'Databáze opravena.';

  @override
  String get uncheck => 'Odznačit';

  @override
  String get toggle => 'Přepnout';

  @override
  String get action => 'Akce';

  @override
  String get habit => 'Zvyk';

  @override
  String get sort => 'Řadit';

  @override
  String get manually => 'Ručně';

  @override
  String get byName => 'Abecedně';

  @override
  String get byColor => 'Podle barvy';

  @override
  String get byScore => 'Podle skóre';

  @override
  String get byStatus => 'Podle stavu';

  @override
  String get export => 'Export';

  @override
  String get longPressToEdit => 'Stiskněte a držte pro změnu hodnoty';

  @override
  String get value => 'Hodnota';

  @override
  String get calendar => 'Kalendář';

  @override
  String get unit => 'Jednotka';

  @override
  String get targetType => 'Typ Cíle';

  @override
  String get targetTypeAtLeast => 'Minimálně';

  @override
  String get targetTypeAtMost => 'Maximálně';

  @override
  String get exampleQuestionBoolean => 'např. Cvičil jsi dnes?';

  @override
  String get question => 'Otázka';

  @override
  String get target => 'Cíl';

  @override
  String get yes => 'Ano';

  @override
  String get no => 'Ne';

  @override
  String get customizeNotificationSummary =>
      'Změnit zvuk, vibrace, světlo a další nastavení upozornění';

  @override
  String get customizeNotification => 'Přizpůsobit upozornění';

  @override
  String get prefViewPrivacy => 'Zobrazit zásady ochrany osobních údajů';

  @override
  String get viewAllContributors => 'Zobrazit všechny přispěvatele…';

  @override
  String get database => 'Databáze';

  @override
  String get widgetOpacityTitle => 'Průhlednost widgetu';

  @override
  String get widgetOpacityDescription =>
      'Upravuje průhlednost pozadí widgetu na domovské obrazovce.';

  @override
  String get firstDayOfTheWeek => 'První den v týdnu';

  @override
  String get defaultReminderQuestion => 'Dokončili jste dnes tento návyk?';

  @override
  String get notes => 'Poznámky';

  @override
  String get exampleNotes => '(nepovinné)';

  @override
  String get yesOrNoExample =>
      'např. Vzbudil ses dnes brzy? Cvičil jsi dnes? Hrál jsi šachy?';

  @override
  String get measurable => 'Měřitelný';

  @override
  String get measurableExample =>
      'např. Kolik kilometrů jsi dnes uběhl? Kolik stránek jsi dnes přečetl?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 krát týdně';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 krát za měsíc';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 krát za $p2 dní';
  }

  @override
  String get yesOrNoShortExample => 'např. Cvičení';

  @override
  String get color => 'Barva';

  @override
  String get exampleTarget => 'např. 15';

  @override
  String get measurableShortExample => 'např. Běh';

  @override
  String get measurableQuestionExample =>
      'např. Kolik kilometrů jsi dnes uběhl?';

  @override
  String get measurableUnitsExample => 'např. Kilometry';

  @override
  String get everyMonth => 'Každý měsíc';

  @override
  String get validationCannotBeBlank => 'Musíte vyplnit';

  @override
  String get today => 'Dnes';

  @override
  String get enter => 'Vyplnit';

  @override
  String get noHabits => 'Žádné návyky nenalezeny';

  @override
  String get noNumericalHabits => 'Žádné měřitelné návyky nenalezeny';

  @override
  String get noBooleanHabits => 'Nenalezeny žádné \"ano/ne\" návyky';

  @override
  String get increment => 'Zvýšit';

  @override
  String get decrement => 'Snížit';

  @override
  String get prefSkipTitle => 'Umožnit přeskakování dnů';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Klikněte dvakrát pro přeskočení namísto zaškrtnutí. Pomlčka nezmění vaše skóre, ani nepřeruší vaši sérii.';

  @override
  String get prefUnknownTitle => 'Zobrazit otazník pro chybějící data';

  @override
  String get prefUnknownDescription =>
      'Odlište dny bez údajů od nesplněného návyku. Pro zadání \"nesplněno\", klikněte dvakrát.';

  @override
  String get youAreNowADeveloper => 'Nyní jste vývojář';

  @override
  String get activityNotFound => 'Nenalezen program podporující tento krok';

  @override
  String get prefMidnightDelayTitle => 'Prodloužit den o pár hodin po půlnoci';

  @override
  String get prefMidnightDelayDescription =>
      'Počkat do tří ráno pro zobrazení nového dne. Užitečné, pokud chodíte spát po půlnoci. Vyžaduje restartování aplikace.';

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
      other: 'Návyky upraveny',
      many: 'Návyky upraveny',
      few: 'Návyky upraveny',
      one: 'Návyk upraven',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návyky odstraněny',
      many: 'Návyky odstraněny',
      few: 'Návyky odstraněny',
      one: 'Návyk odstraněn',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návyky archivovány',
      many: 'Návyky archivovány',
      few: 'Návyky archivovány',
      one: 'Návyk archivován',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návyky obnoveny',
      many: 'Návyky obnoveny',
      few: 'Návyky obnoveny',
      one: 'Návyk obnoven',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Odstranit návyky?',
      many: 'Odstranit návyky?',
      few: 'Odstranit návyky?',
      one: 'Odstranit návyk?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Návyky budou trvale odstraněny. Tento krok je nevratný.',
      many: 'Návyky budou trvale odstraněny. Tento krok je nevratný.',
      few: 'Návyky budou trvale odstraněny. Tento krok je nevratný.',
      one: 'Návyk bude trvale odstraněn. Tento krok je nevratný.',
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
