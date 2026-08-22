// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class L10nNl extends L10n {
  L10nNl([String locale = 'nl']) : super(locale);

  @override
  String get appName => 'Loop Gewoonte tracker';

  @override
  String get mainActivityTitle => 'Gewoontes';

  @override
  String get actionSettings => 'Instellingen';

  @override
  String get edit => 'Wijzig';

  @override
  String get delete => 'Verwijder';

  @override
  String get archive => 'Archiveer';

  @override
  String get unarchive => 'Dearchiveren';

  @override
  String get addHabit => 'Nieuwe gewoonte';

  @override
  String get colorPickerDefaultTitle => 'Verander kleur';

  @override
  String get toastHabitCreated => 'Gewoonte aangemaakt.';

  @override
  String get habitStrength => 'Gewoonte-sterkte';

  @override
  String get history => 'Geschiedenis';

  @override
  String get clear => 'Wis';

  @override
  String get reminder => 'Herinnering';

  @override
  String get save => 'Opslaan';

  @override
  String get streaks => 'Reeksen';

  @override
  String get noHabitsFound => 'Je hebt geen actieve gewoontes';

  @override
  String get noHabitsLeftToDo => 'Je bent klaar voor vandaag!';

  @override
  String get longPressToToggle =>
      'Houdt ingedrukt om te selecteren of deselecteren';

  @override
  String get reminderOff => 'Uit';

  @override
  String get createHabit => 'Gewoonte aanmaken';

  @override
  String get editHabit => 'Wijzig gewoonte';

  @override
  String get check => 'Voltooid';

  @override
  String get snooze => 'Later';

  @override
  String get introTitle1 => 'Welkom';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker helpt je om goede gewoontes te creëren en te onderhouden.';

  @override
  String get introTitle2 => 'Creëer enkele nieuwe gewoontes';

  @override
  String get introDescription2 =>
      'Plaats iedere dag, na het uitvoeren van jouw gewoonte, een vinkje in de app.';

  @override
  String get introTitle4 => 'Volg jouw voortgang';

  @override
  String get introDescription4 =>
      'Gedetailleerde grafieken tonen je hoe jouw gewoontes met de tijd verbeteren.';

  @override
  String get interval15Minutes => '15 minuten';

  @override
  String get interval30Minutes => '30 minuten';

  @override
  String get interval1Hour => '1 uur';

  @override
  String get interval2Hour => '2 uur';

  @override
  String get interval4Hour => '4 uur';

  @override
  String get interval8Hour => '8 uur';

  @override
  String get interval24Hour => '24 uur';

  @override
  String get intervalAlwaysAsk => 'Altijd vragen';

  @override
  String get intervalCustom => 'Aangepast...';

  @override
  String get prefToggleTitle => 'Wijzig herhalingen door kort indrukken';

  @override
  String get prefToggleDescription2 =>
      'Zet vinkjes met een enkele keer drukken in plaats van ingedrukt te houden.';

  @override
  String get prefRateThisApp => 'Beoordeel deze app in Google Play';

  @override
  String get prefSendFeedback => 'Stuur feedback aan de ontwikkelaar';

  @override
  String get prefViewSourceCode => 'Bekijk de broncode op GitHub';

  @override
  String get links => 'Links';

  @override
  String get name => 'Naam';

  @override
  String get settings => 'Instellingen';

  @override
  String get selectSnoozeDelay => 'Snooze vertraging selecteren';

  @override
  String get hintTitle => 'Wist je dat?';

  @override
  String get hintDrag =>
      'Om de rijen te ordenen, houdt de gewoonte ingedrukt en sleep het naar de gewenste plek.';

  @override
  String get hintLandscape =>
      'Je kunt meer dagen zien door de telefoon in landschapsmodus te zetten.';

  @override
  String get habitNotFound => 'Gewoonte verwijderd / niet gevonden';

  @override
  String get weekends => 'Weekends';

  @override
  String get anyWeekday => 'Maandag tot vrijdag';

  @override
  String get anyDay => 'Elke dag van de week';

  @override
  String get selectWeekdays => 'Selecteer dagen';

  @override
  String get exportToCsv => 'Exporteer als CSV';

  @override
  String get doneLabel => 'Voltooid';

  @override
  String get clearLabel => 'Wis';

  @override
  String get selectHours => 'Selecteer uren';

  @override
  String get selectMinutes => 'Selecteer minuten';

  @override
  String get about => 'Over';

  @override
  String get translators => 'Vertalers';

  @override
  String get developers => 'Ontwikkelaars';

  @override
  String versionN(String p1) {
    return 'Versie $p1';
  }

  @override
  String get frequency => 'Frequentie';

  @override
  String get checkmark => 'Vinkje';

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
  String get bestStreaks => 'Beste reeksen';

  @override
  String get everyDay => 'Iedere dag';

  @override
  String get everyWeek => 'Iedere week';

  @override
  String get help => 'Hulp en veelgestelde vragen';

  @override
  String get couldNotExport => 'Het exporteren van de data is mislukt.';

  @override
  String get couldNotImport => 'Importeren van data mislukt.';

  @override
  String get fileNotRecognized => 'Bestand niet herkend.';

  @override
  String get habitsImported => 'Gewoontes succesvol geïmporteerd.';

  @override
  String get importData => 'Importeer gegevens';

  @override
  String get exportFullBackup => 'Exporteer volledige backup';

  @override
  String get importDataSummary =>
      'Ondersteunt volledige back-ups geëxporteerd door deze app, evenals bestanden die worden gegenereerd door Tickmate, HabitBull of Rewire. Zie de veel gestelde vragen voor meer informatie.';

  @override
  String get exportAsCsvSummary =>
      'Genereert bestanden die geopend kunnen worden door spreadsheet software zoals Microsoft Excel of OpenOffice Calc. Dit bestand kan niet opnieuw worden geïmporteerd.';

  @override
  String get exportFullBackupSummary =>
      'Genereert een bestand met al uw gegevens. Dit bestand kan ook terug geïmporteerd worden.';

  @override
  String get selectPublicBackupFolder => 'Openbare back-upmap selecteren';

  @override
  String get noPublicBackupFolderSelected => 'Geen map geselecteerd';

  @override
  String get bugReportFailed =>
      'Het genereren van het foutenrapport is mislukt.';

  @override
  String get generateBugReport => 'Genereer foutenrapport';

  @override
  String get troubleshooting => 'Probleemoplossing';

  @override
  String get helpTranslate => 'Help deze app te vertalen';

  @override
  String get nightMode => 'Nachtmodus';

  @override
  String get usePureBlack => 'Gebruik puur zwart bij het donkere thema';

  @override
  String get pureBlackDescription =>
      'Vervangt grijze achtergronden door puur zwart in het donkere thema. Vermindert batterijgebruik bij telefoons met AMOLED scherm.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Omgekeerde volgorde van dagen';

  @override
  String get reverseDaysDescription =>
      'Toon dagen in omgekeerde volgorde op het hoofdscherm';

  @override
  String get day => 'Dag';

  @override
  String get week => 'Week';

  @override
  String get month => 'Maand';

  @override
  String get quarter => 'Kwartaal';

  @override
  String get year => 'Jaar';

  @override
  String get total => 'Totaal';

  @override
  String get yesOrNo => 'Ja of Nee';

  @override
  String everyXDays(int p1) {
    return 'Iedere $p1 dagen';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Iedere $p1 weken';
  }

  @override
  String get score => 'Score';

  @override
  String get reminderSound => 'Herinneringsgeluid';

  @override
  String get none => 'Stil';

  @override
  String get filter => 'Filteren';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Verberg voltooide';

  @override
  String get hideEntered => 'Verberg ingevoerde';

  @override
  String get hideArchived => 'Verberg gearchiveerde';

  @override
  String get stickyNotifications => 'Maak meldingen persistent';

  @override
  String get stickyNotificationsDescription =>
      'Voorkom dat meldingen weggehaald kunnen worden.';

  @override
  String get ledNotifications => 'Notificatie licht';

  @override
  String get ledNotificationsDescription =>
      'Toont een knipperend licht voor herinneringen. Alleen beschikbaar in telefoons met LED-meldingsverlichting.';

  @override
  String get repairDatabase => 'Database repareren';

  @override
  String get databaseRepaired => 'Database gerepareerd.';

  @override
  String get uncheck => 'Deselecteren';

  @override
  String get toggle => 'Schakel';

  @override
  String get action => 'Actie';

  @override
  String get habit => 'Gewoonte';

  @override
  String get sort => 'Sorteren';

  @override
  String get manually => 'Handmatig';

  @override
  String get byName => 'Op naam';

  @override
  String get byColor => 'Op kleur';

  @override
  String get byScore => 'Op score';

  @override
  String get byStatus => 'Per status';

  @override
  String get export => 'Exporteren';

  @override
  String get longPressToEdit => 'Ingedrukt houden om de waarde te wijzigen';

  @override
  String get value => 'Waarde';

  @override
  String get calendar => 'Kalender';

  @override
  String get unit => 'Eenheid';

  @override
  String get targetType => 'Doeltype';

  @override
  String get targetTypeAtLeast => 'Minimaal';

  @override
  String get targetTypeAtMost => 'Maximaal';

  @override
  String get exampleQuestionBoolean => 'bijv. Heb je vandaag gesport?';

  @override
  String get question => 'Vraag';

  @override
  String get target => 'Doel';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nee';

  @override
  String get customizeNotificationSummary =>
      'Wijzig geluid, trilling, licht en andere instellingen voor meldingen';

  @override
  String get customizeNotification => 'Meldingen aanpassen';

  @override
  String get prefViewPrivacy => 'Privacybeleid bekijken';

  @override
  String get viewAllContributors => 'Bekijk alle bijdragers&#8230;';

  @override
  String get database => 'Database';

  @override
  String get widgetOpacityTitle => 'Widget doorzichtigheid';

  @override
  String get widgetOpacityDescription =>
      'Maakt widgets transparanter of minder doorschijnend op je start scherm.';

  @override
  String get firstDayOfTheWeek => 'Eerste dag van de week';

  @override
  String get defaultReminderQuestion =>
      'Heb je deze gewoonte vandaag voltooid?';

  @override
  String get notes => 'Notities';

  @override
  String get exampleNotes => '(Optioneel)';

  @override
  String get yesOrNoExample =>
      'bijv. Ben je vandaag vroeg wakker geworden? Heb je gesport? Heb je geschaakt?';

  @override
  String get measurable => 'Meetbaar';

  @override
  String get measurableExample =>
      'bijv. Hoeveel kilometer heb je vandaag gelopen? Hoeveel pagina\'s heb je gelezen?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 keer per week';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 keer per maand';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 keer in  $p2 dagen';
  }

  @override
  String get yesOrNoShortExample => 'bijv. Sporten';

  @override
  String get color => 'Kleur';

  @override
  String get exampleTarget => 'bijv. 15';

  @override
  String get measurableShortExample => 'bijv. Hardlopen';

  @override
  String get measurableQuestionExample =>
      'bijv. Hoeveel kilometer heb je vandaag hardgelopen?';

  @override
  String get measurableUnitsExample => 'bijv. kilometers';

  @override
  String get everyMonth => 'Elke maand';

  @override
  String get validationCannotBeBlank => 'Mag niet leeg zijn';

  @override
  String get today => 'Vandaag';

  @override
  String get enter => 'Voer in';

  @override
  String get noHabits => 'Geen gewoontes gevonden';

  @override
  String get noNumericalHabits => 'Geen meetbare gewoontes gevonden';

  @override
  String get noBooleanHabits => 'Geen ja-of-nee-gewoontes gevonden';

  @override
  String get increment => 'Verhogen';

  @override
  String get decrement => 'Verlagen';

  @override
  String get prefSkipTitle => 'Overgeslagen dagen inschakelen';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Schakel tweemaal om een overgeslagen dag toe te voegen in plaats van een vinkje. Overgeslagen dagen houden je score ongewijzigd en verbreken je streak niet.';

  @override
  String get prefUnknownTitle =>
      'Vraagtekens weergeven wanneer gegevens ontbreken';

  @override
  String get prefUnknownDescription =>
      'Onderscheid dagen zonder gegevens van daadwerkelijke verlopen dagen. Klik twee keer om een verlopen dag in te voeren.';

  @override
  String get youAreNowADeveloper => 'Je bent nu een ontwikkelaar!';

  @override
  String get activityNotFound =>
      'Er is geen app gevonden om deze actie uit te voeren.';

  @override
  String get prefMidnightDelayTitle =>
      'Verleng de dag tot een paar uur na middernacht';

  @override
  String get prefMidnightDelayDescription =>
      'Wacht tot 3:00 uur om een nieuwe dag te beginnen. Handig als je normaal gesproken na middernacht gaat slapen. Dit vereist het opnieuw opstarten van de app.';

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
      other: 'Gewoontes gewijzigd',
      one: 'Gewoonte gewijzigd',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewoontes verwijderd',
      one: 'Gewoontes verwijderd',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewoontes gearchiveerd',
      one: 'Gewoontes gearchiveerd',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewoontes hersteld uit archief',
      one: 'Gewoonte niet gearchiveerd',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewoontes verwijderen?',
      one: 'Verwijder gewoontes',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'De gewoontes zullen permanent verwijderd worden. Deze actie kan niet ongedaan gemaakt worden.',
      one:
          'De gewoonte zal permanent verwijderd worden. Deze actie kan niet ongedaan gemaakt worden.',
    );
    return '$_temp0';
  }
}
