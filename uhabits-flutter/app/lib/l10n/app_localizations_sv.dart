// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class L10nSv extends L10n {
  L10nSv([String locale = 'sv']) : super(locale);

  @override
  String get appName => 'Loop Vanedagbok';

  @override
  String get mainActivityTitle => 'Vanor';

  @override
  String get actionSettings => 'Inställningar';

  @override
  String get edit => 'Redigera';

  @override
  String get delete => 'Ta bort';

  @override
  String get archive => 'Arkivera';

  @override
  String get unarchive => 'Ångra arkivering';

  @override
  String get addHabit => 'Lägg till vana';

  @override
  String get colorPickerDefaultTitle => 'Byt färg';

  @override
  String get toastHabitCreated => 'Vana skapad';

  @override
  String get habitStrength => 'Vanestyrka';

  @override
  String get history => 'Historik';

  @override
  String get clear => 'Rensa';

  @override
  String get reminder => 'Påminnelse';

  @override
  String get save => 'Spara';

  @override
  String get streaks => 'Streaks';

  @override
  String get noHabitsFound => 'Du har inga aktiva vanor';

  @override
  String get noHabitsLeftToDo => 'Du är klar för idag!';

  @override
  String get longPressToToggle =>
      'Tryck-och-håll för att markera eller avmarkera';

  @override
  String get reminderOff => 'Av';

  @override
  String get createHabit => 'Skapa vana';

  @override
  String get editHabit => 'Redigera vana';

  @override
  String get check => 'Markera';

  @override
  String get snooze => 'Senare';

  @override
  String get introTitle1 => 'Välkommen';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker hjälper dig att skapa och bibehålla goda vanor.';

  @override
  String get introTitle2 => 'Skapa några nya vanor';

  @override
  String get introDescription2 =>
      'Efter varje dag när du utfört din vana så markerar du den i appen.';

  @override
  String get introTitle4 => 'Följ dina framsteg';

  @override
  String get introDescription4 =>
      'Detaljerade grafer visar dig hur dina vanor förbättras över tid.';

  @override
  String get interval15Minutes => '15 minuter';

  @override
  String get interval30Minutes => '30 minuter';

  @override
  String get interval1Hour => '1 timme';

  @override
  String get interval2Hour => '2 timmar';

  @override
  String get interval4Hour => '4 timmar';

  @override
  String get interval8Hour => '8 timmar';

  @override
  String get interval24Hour => '24 timmar';

  @override
  String get intervalAlwaysAsk => 'Fråga alltid';

  @override
  String get intervalCustom => 'Anpassad...';

  @override
  String get prefToggleTitle => 'Växla med snabb tryckning';

  @override
  String get prefToggleDescription2 =>
      'Sätt bockar med en enkel tryckning i stället för att trycka och hålla nere.';

  @override
  String get prefRateThisApp => 'Betygsätt oss på Google Play';

  @override
  String get prefSendFeedback => 'Skicka feedback till utvecklarna';

  @override
  String get prefViewSourceCode => 'Visa källkod på GitHub';

  @override
  String get links => 'Länkar';

  @override
  String get name => 'Namn';

  @override
  String get settings => 'Inställningar';

  @override
  String get selectSnoozeDelay => 'Välj snoozelängd';

  @override
  String get hintTitle => 'Visste du att?';

  @override
  String get hintDrag =>
      'För att flytta på poster - tryck och håll nere på den vana du vill flytta, sedan flytta den till önskad plats.';

  @override
  String get hintLandscape =>
      'Du kan se mer dagar genom att hålla telefonen i landskapsläge.';

  @override
  String get habitNotFound => 'Vana borttagen / hittades inte';

  @override
  String get weekends => 'Helger';

  @override
  String get anyWeekday => 'Måndag till fredag';

  @override
  String get anyDay => 'Vilken dag som helst';

  @override
  String get selectWeekdays => 'Välj dagar';

  @override
  String get exportToCsv => 'Exportera data (CSV)';

  @override
  String get doneLabel => 'Klart';

  @override
  String get clearLabel => 'Rensa';

  @override
  String get selectHours => 'Välj timmar';

  @override
  String get selectMinutes => 'Välj minuter';

  @override
  String get about => 'Om';

  @override
  String get translators => 'Översättare';

  @override
  String get developers => 'Utvecklare';

  @override
  String versionN(String p1) {
    return 'Version $p1';
  }

  @override
  String get frequency => 'Frekvens';

  @override
  String get checkmark => 'Kryssruta';

  @override
  String get checkmarkStackWidget => 'Stapelwidget med kryssruta';

  @override
  String get frequencyStackWidget => 'Stapelwidget med frekvens';

  @override
  String get scoreStackWidget => 'Stapelwidget med poäng';

  @override
  String get historyStackWidget => 'Stapelwidget med historik';

  @override
  String get streaksStackWidget => 'Stapelwidget med serier';

  @override
  String get bestStreaks => 'Bästa serie';

  @override
  String get everyDay => 'Varje dag';

  @override
  String get everyWeek => 'Varje vecka';

  @override
  String get help => 'Hjälp och FAQ';

  @override
  String get couldNotExport => 'Det gick inte att exportera.';

  @override
  String get couldNotImport => 'Det gick inte att importera.';

  @override
  String get fileNotRecognized => 'Kunde inte känna igen filen.';

  @override
  String get habitsImported => 'Import av dina vanor lyckades.';

  @override
  String get importData => 'Importera data';

  @override
  String get exportFullBackup => 'Exportera backup';

  @override
  String get importDataSummary =>
      'Appen har stöd att importera data från denna app, men även backuper från Tickmate, Habitbull eller Rewire. Läs FAQ om du vill meta mer.';

  @override
  String get exportAsCsvSummary =>
      'Filerna genererade kan öppnas i Microsoft Excel eller OpenOffice Calc. Däremot kan denna fil inte importeras tillbaka till appen.';

  @override
  String get exportFullBackupSummary =>
      'Generera en fil som innehåller all din data. Denna fil kan importas tillbaka till appen.';

  @override
  String get selectPublicBackupFolder =>
      'Välj offentlig säkerhetskopieringsmapp';

  @override
  String get noPublicBackupFolderSelected => 'Ingen mapp vald';

  @override
  String get bugReportFailed => 'Det gick inte att generera felrapport.';

  @override
  String get generateBugReport => 'Generera felrapport';

  @override
  String get troubleshooting => 'Felsökning';

  @override
  String get helpTranslate => 'Hjälp till att översätta appen';

  @override
  String get nightMode => 'Nattläge';

  @override
  String get usePureBlack => 'Använd svart färg i nattläge';

  @override
  String get pureBlackDescription =>
      'Ersätter gråa bakgrunder med svart färg i nattläge. Reducerar batterianvändningen för telefoner med AMOLED-skärm.';

  @override
  String get interfacePreferences => 'Gränssnitt';

  @override
  String get reverseDays => 'Omvänd ordning på dagar';

  @override
  String get reverseDaysDescription => 'Visar dagar i omvänd ordning i appen';

  @override
  String get day => 'Dag';

  @override
  String get week => 'Vecka';

  @override
  String get month => 'Månad';

  @override
  String get quarter => 'Kvartal';

  @override
  String get year => 'År';

  @override
  String get total => 'Totalt';

  @override
  String get yesOrNo => 'Ja eller Nej';

  @override
  String everyXDays(int p1) {
    return 'Var $p1:e dag';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Var $p1:e vecka';
  }

  @override
  String get score => 'Poäng';

  @override
  String get reminderSound => 'Påminnelseljud';

  @override
  String get none => 'Inget';

  @override
  String get filter => 'Filtrera';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Dölj slutförda';

  @override
  String get hideEntered => 'Dölj inmatade';

  @override
  String get hideArchived => 'Dölj arkiverade';

  @override
  String get stickyNotifications => 'Gör notifikationer permanenta';

  @override
  String get stickyNotificationsDescription =>
      'Förhindrar att notifikationer stängs.';

  @override
  String get ledNotifications => 'Aviseringsindikator';

  @override
  String get ledNotificationsDescription =>
      'Visar ett blinkande ljus för påminnelser. Endast tillgängligt för telefoner med LED-indikator.';

  @override
  String get repairDatabase => 'Reparera databas';

  @override
  String get databaseRepaired => 'Databasen reparerad.';

  @override
  String get uncheck => 'Avmarkera';

  @override
  String get toggle => 'Växla';

  @override
  String get action => 'Åtgärd';

  @override
  String get habit => 'Vana';

  @override
  String get sort => 'Sortera';

  @override
  String get manually => 'Manuellt';

  @override
  String get byName => 'Efter namn';

  @override
  String get byColor => 'Efter färg';

  @override
  String get byScore => 'Efter poäng';

  @override
  String get byStatus => 'Efter status';

  @override
  String get export => 'Exportera';

  @override
  String get longPressToEdit => 'Tryck och håll ned för att ändra värdet';

  @override
  String get value => 'Värde';

  @override
  String get calendar => 'Kalender';

  @override
  String get unit => 'Enhet';

  @override
  String get targetType => 'Måltyp';

  @override
  String get targetTypeAtLeast => 'Minst';

  @override
  String get targetTypeAtMost => 'Högst';

  @override
  String get exampleQuestionBoolean => 't.ex. Tränade du idag?';

  @override
  String get question => 'Fråga';

  @override
  String get target => 'Mål';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nej';

  @override
  String get customizeNotificationSummary =>
      'Ändra ljud, vibration, ljus och andra aviseringsinställningar';

  @override
  String get customizeNotification => 'Anpassa aviseringar';

  @override
  String get prefViewPrivacy => 'Visa integritetspolicy';

  @override
  String get viewAllContributors => 'Visa alla medverkande&#8230;';

  @override
  String get database => 'Databas';

  @override
  String get widgetOpacityTitle => 'Widgetopacitet';

  @override
  String get widgetOpacityDescription =>
      'Gör widgetar mer eller mindre transparenta på hemskärmen.';

  @override
  String get firstDayOfTheWeek => 'Första dagen i veckan';

  @override
  String get defaultReminderQuestion => 'Har du genomfört denna vana idag?';

  @override
  String get notes => 'Anteckningar';

  @override
  String get exampleNotes => '(valfritt)';

  @override
  String get yesOrNoExample =>
      't.ex. Vaknade du tidigt idag? Tränade du? Spelade du schack?';

  @override
  String get measurable => 'Mätbar';

  @override
  String get measurableExample =>
      't.ex. Hur många kilometer sprang du idag? Hur många sidor läste du?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 gånger per vecka';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 gånger per månad';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 gånger per $p2 dag(ar)';
  }

  @override
  String get yesOrNoShortExample => 't.ex. Träna';

  @override
  String get color => 'Färg';

  @override
  String get exampleTarget => 't.ex. 15';

  @override
  String get measurableShortExample => 't.ex. Spring';

  @override
  String get measurableQuestionExample =>
      't.ex. Hur många kilometer sprang du idag?';

  @override
  String get measurableUnitsExample => 't.ex. kilometer';

  @override
  String get everyMonth => 'Varje månad';

  @override
  String get validationCannotBeBlank => 'Får inte vara tomt';

  @override
  String get today => 'Idag';

  @override
  String get enter => 'Ange';

  @override
  String get noHabits => 'Inga vanor hittades';

  @override
  String get noNumericalHabits => 'Inga mätbara vanor hittades';

  @override
  String get noBooleanHabits => 'Inga ja-eller-nej-vanor hittades';

  @override
  String get increment => 'Öka';

  @override
  String get decrement => 'Minska';

  @override
  String get prefSkipTitle => 'Aktivera överhoppning av dagar';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Växla två gånger för att hoppa över istället för att bocka för. Att hoppa över behåller dina poäng oförändrade och bryter inte din serie.';

  @override
  String get prefUnknownTitle => 'Visa frågetecken för data som saknas';

  @override
  String get prefUnknownDescription =>
      'Skilj dagar utan data från faktiska misslyckanden. För att ange ett misslyckanden, växla två gånger.';

  @override
  String get youAreNowADeveloper => 'Du är nu en utvecklare';

  @override
  String get activityNotFound => 'Ingen app som stödjer åtgärden hittades.';

  @override
  String get prefMidnightDelayTitle =>
      'Förläng dagen några timmar efter midnatt';

  @override
  String get prefMidnightDelayDescription =>
      'Vänta till 3:00 innan en ny dag visas. Användbart om du vanligtvis går och lägger dig efter midnatt. Kräver omstart av appen.';

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
      other: 'Vanorna ändrades',
      one: 'Vanan ändrades',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vanorna raderades',
      one: 'Vanan raderades',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vanorna arkiverades',
      one: 'Vanan arkiverades',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vanorna avarkiverades',
      one: 'Vanan avarkiverades',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera vanor?',
      one: 'Radera vana?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vanorna kommer att raderas permanent. Denna åtgärd går inte att ångra.',
      one:
          'Vanan kommer att raderas permanent. Denna åtgärd går inte att ångra.',
    );
    return '$_temp0';
  }
}
