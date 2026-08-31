// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class L10nDe extends L10n {
  L10nDe([String locale = 'de']) : super(locale);

  @override
  String get overview => 'Übersicht';

  @override
  String get appName => 'Loop - Gewohnheiten Tracking';

  @override
  String get mainActivityTitle => 'Gewohnheiten';

  @override
  String get actionSettings => 'Einstellungen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get delete => 'Löschen';

  @override
  String get archive => 'Archivieren';

  @override
  String get unarchive => 'Aus Archiv zurückholen';

  @override
  String get addHabit => 'Gewohnheit hinzufügen';

  @override
  String get colorPickerDefaultTitle => 'Farbe ändern';

  @override
  String get toastHabitCreated => 'Gewohnheit erstellt';

  @override
  String get habitStrength => 'Wertung';

  @override
  String get history => 'Verlauf';

  @override
  String get clear => 'Löschen';

  @override
  String get reminder => 'Erinnerung';

  @override
  String get save => 'Speichern';

  @override
  String get streaks => 'Serien';

  @override
  String get noHabitsFound => 'Du hast keine aktiven Gewohnheiten';

  @override
  String get noHabitsLeftToDo => 'Alle Gewohnheiten für heute erledigt!';

  @override
  String get longPressToToggle => 'Tippe und halte um aus- bzw. abzuwählen';

  @override
  String get reminderOff => 'Aus';

  @override
  String get createHabit => 'Gewohnheit erstellen';

  @override
  String get editHabit => 'Gewohnheit bearbeiten';

  @override
  String get check => 'Abhaken';

  @override
  String get snooze => 'Später';

  @override
  String get introTitle1 => 'Willkommen';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker hilft dir dabei, gute Gewohnheiten zu entwickeln.';

  @override
  String get introTitle2 => 'Erstelle neue Gewohnheiten';

  @override
  String get introDescription2 =>
      'Hake die Gewohnheit jeden Tag in der App ab, nachdem du sie erledigt hast.';

  @override
  String get introTitle4 => 'Verfolge deinen Fortschritt';

  @override
  String get introDescription4 =>
      'Detaillierte Diagramme zeigen dir an, wie sich deine Gewohnheiten entwickelt haben.';

  @override
  String get interval15Minutes => '15 Minuten';

  @override
  String get interval30Minutes => '30 Minuten';

  @override
  String get interval1Hour => '1 Stunde';

  @override
  String get interval2Hour => '2 Stunden';

  @override
  String get interval4Hour => '4 Stunden';

  @override
  String get interval8Hour => '8 Stunden';

  @override
  String get interval24Hour => '24 Stunden';

  @override
  String get intervalAlwaysAsk => 'Immer fragen';

  @override
  String get intervalCustom => 'Benutzerdefiniert...';

  @override
  String get prefToggleTitle => 'Markierung durch kurzes Tippen ändern';

  @override
  String get prefToggleDescription2 =>
      'Häkchen durch einfaches Antippen setzen, anstatt durch Drücken und Halten.';

  @override
  String get prefRateThisApp => 'Bewerte diese App auf Google Play';

  @override
  String get prefSendFeedback => 'Sende dem Entwickler Feedback';

  @override
  String get prefViewSourceCode => 'Zeige den Quellcode auf GitHub';

  @override
  String get links => 'Links';

  @override
  String get name => 'Name';

  @override
  String get settings => 'Einstellungen';

  @override
  String get selectSnoozeDelay => 'Schlummer-Intervall auswählen';

  @override
  String get hintTitle => 'Wusstest du?';

  @override
  String get hintDrag =>
      'Um Einträge umzusortieren, tippe, halte und ziehe sie an die richtige Stelle.';

  @override
  String get hintLandscape =>
      'Du kannst mehr Tage sehen, wenn du dein Smartphone quer hältst.';

  @override
  String get habitNotFound => 'Gewohnheit gelöscht / nicht gefunden';

  @override
  String get weekends => 'An Wochenenden';

  @override
  String get anyWeekday => 'Montag bis Freitag';

  @override
  String get anyDay => 'Jeden Tag';

  @override
  String get selectWeekdays => 'Tage auswählen';

  @override
  String get exportToCsv => 'Als CSV exportieren';

  @override
  String get doneLabel => 'Fertig';

  @override
  String get clearLabel => 'Löschen';

  @override
  String get selectHours => 'Stunden auswählen';

  @override
  String get selectMinutes => 'Minuten auswählen';

  @override
  String get about => 'Über Loop';

  @override
  String get translators => 'Übersetzer';

  @override
  String get developers => 'Entwickler';

  @override
  String versionN(String p1) {
    return 'Version $p1';
  }

  @override
  String get frequency => 'Häufigkeit';

  @override
  String get checkmark => 'Häkchen';

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
  String get bestStreaks => 'Beste Serien';

  @override
  String get everyDay => 'Jeden Tag';

  @override
  String get everyWeek => 'Jede Woche';

  @override
  String get help => 'Hilfe & FAQ';

  @override
  String get couldNotExport => 'Fehler beim Exportieren der Daten.';

  @override
  String get couldNotImport => 'Fehler beim Importieren der Daten.';

  @override
  String get fileNotRecognized => 'Datei nicht erkannt.';

  @override
  String get habitsImported => 'Gewohnheiten erfolgreich importiert.';

  @override
  String get importData => 'Daten importieren';

  @override
  String get exportFullBackup => 'Vollständige Sicherung exportieren';

  @override
  String get importDataSummary =>
      'Unterstützt vollständige Sicherungen dieser App, sowie von Tickmate, HabitBull und Rewire erzeugte Sicherungen. Siehe FAQ für weitere Informationen.';

  @override
  String get exportAsCsvSummary =>
      'Erstellt Dateien, die von Tabellenkalkulationsprogrammen wie Microsoft Excel oder LibreOffice Calc geöffnet werden können. Diese Dateien können nicht wieder importiert werden.';

  @override
  String get exportFullBackupSummary =>
      'Erstellt eine Datei, die alle deine Daten enthält. Diese Datei kann wieder importiert werden.';

  @override
  String get selectPublicBackupFolder => 'Öffentlichen Backup-Ordner auswählen';

  @override
  String get noPublicBackupFolderSelected => 'Kein Ordner ausgewählt';

  @override
  String get bugReportFailed => 'Fehler beim Erstellen eines Fehlerberichts.';

  @override
  String get generateBugReport => 'Erstelle einen Fehlerbericht';

  @override
  String get troubleshooting => 'Fehlerbehebung';

  @override
  String get helpTranslate => 'Hilf mit, diese App zu übersetzen';

  @override
  String get nightMode => 'Nachtmodus';

  @override
  String get usePureBlack => 'Verwende reines Schwarz im Nachtmodus';

  @override
  String get pureBlackDescription =>
      'Ersetzt im Nachtmodus das Grau des Hintergrunds durch Schwarz. Reduziert den Stromverbrauch von Smartphones mit AMOLED Displays.';

  @override
  String get interfacePreferences => 'Oberfläche';

  @override
  String get reverseDays => 'Kehre die Tagesreihenfolge um';

  @override
  String get reverseDaysDescription =>
      'Zeigt die Tage im Hauptfenster in umgekehrter Reihenfolge an.';

  @override
  String get day => 'Tag';

  @override
  String get week => 'Woche';

  @override
  String get month => 'Monat';

  @override
  String get quarter => 'Quartal';

  @override
  String get year => 'Jahr';

  @override
  String get total => 'Insgesamt';

  @override
  String get yesOrNo => 'Ja / Nein';

  @override
  String everyXDays(int p1) {
    return 'Alle $p1 Tage';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Alle $p1 Wochen';
  }

  @override
  String get score => 'Wertung';

  @override
  String get reminderSound => 'Erinnerungston';

  @override
  String get none => 'Keiner';

  @override
  String get filter => 'Filter';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Erledigte verbergen';

  @override
  String get hideEntered => 'Eingegebenes ausblenden';

  @override
  String get hideArchived => 'Archivierte verbergen';

  @override
  String get stickyNotifications => 'Fixiere Benachrichtigungen';

  @override
  String get stickyNotificationsDescription =>
      'Verhindert das Wegwischen von Benachrichtigungen.';

  @override
  String get ledNotifications => 'Benachrichtigungs-LED';

  @override
  String get ledNotificationsDescription =>
      'Blinkende LED für Erinnerungen anzeigen. Nur verfügbar in Geräten mit LED Benachrichtigungs-LED.';

  @override
  String get repairDatabase => 'Datenbank reparieren';

  @override
  String get databaseRepaired => 'Datenbank repariert.';

  @override
  String get uncheck => 'Abwählen';

  @override
  String get toggle => 'Umschalten';

  @override
  String get action => 'Aktion';

  @override
  String get habit => 'Gewohnheit';

  @override
  String get sort => 'Sortiere';

  @override
  String get manually => 'Manuell';

  @override
  String get byName => 'Nach Name';

  @override
  String get byColor => 'Nach Farbe';

  @override
  String get byScore => 'Nach Wertung';

  @override
  String get byStatus => 'Nach Zustand';

  @override
  String get export => 'Exportieren';

  @override
  String get longPressToEdit => 'Gedrückt halten, um den Wert zu ändern';

  @override
  String get value => 'Wert';

  @override
  String get calendar => 'Kalender';

  @override
  String get unit => 'Einheit';

  @override
  String get targetType => 'Zieltyp';

  @override
  String get targetTypeAtLeast => 'Mindestens';

  @override
  String get targetTypeAtMost => 'Höchstens';

  @override
  String get exampleQuestionBoolean => 'z.B. Hast du heute trainiert?';

  @override
  String get question => 'Frage';

  @override
  String get target => 'Ziel';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get customizeNotificationSummary =>
      'Töne, Vibrationen, Licht und weitere Einstellungen ändern';

  @override
  String get customizeNotification => 'Benachrichtigungen anpassen';

  @override
  String get prefViewPrivacy => 'Datenschutzrichtlinie anzeigen';

  @override
  String get viewAllContributors => 'Alle Mitwirkende anzeigen…';

  @override
  String get database => 'Datenbank';

  @override
  String get widgetOpacityTitle => 'Widget Deckkraft';

  @override
  String get widgetOpacityDescription =>
      'Stellt die Durchsichtigkeit des Hintergrundes der Widgets auf dem Startbildschirm ein.';

  @override
  String get firstDayOfTheWeek => 'Erster Tag der Woche';

  @override
  String get defaultReminderQuestion =>
      'Hast du diese Gewohnheit heute erledigt?';

  @override
  String get notes => 'Notiz';

  @override
  String get exampleNotes => '(Optional)';

  @override
  String get yesOrNoExample =>
      'z.B. Bist du heute früh wach geworden? Hast du trainiert? Hast du Schach gespielt?';

  @override
  String get measurable => 'Messbar';

  @override
  String get measurableExample =>
      'z.B. Wie viele Kilometer bist du heute gelaufen? Wie viele Seiten hast du gelesen?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 mal pro Woche';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 mal pro Monat';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 Mal in $p2 Tagen';
  }

  @override
  String get yesOrNoShortExample => 'z.B. Übung';

  @override
  String get color => 'Farbe';

  @override
  String get exampleTarget => 'z.B. 15';

  @override
  String get measurableShortExample => 'z.B. Laufen';

  @override
  String get measurableQuestionExample =>
      'z.B. Wie viele Kilometer bist du heute gelaufen?';

  @override
  String get measurableUnitsExample => 'z.B. Kilometer';

  @override
  String get everyMonth => 'Monatlich';

  @override
  String get validationCannotBeBlank => 'Darf nicht leer sein';

  @override
  String get today => 'Heute';

  @override
  String get enter => 'Eingeben';

  @override
  String get noHabits => 'Keine Gewohnheiten gefunden';

  @override
  String get noNumericalHabits => 'Keine messbaren Gewohnheiten gefunden';

  @override
  String get noBooleanHabits => 'Keine Ja-oder-Nein-Gewohnheiten gefunden';

  @override
  String get increment => 'Erhöhen';

  @override
  String get decrement => 'Verringern';

  @override
  String get prefSkipTitle => 'Tage überspringen aktivieren';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Zwei mal markieren, um eine Lücke einzutragen statt abzuhaken. Lücken lassen deine Wertung unverändert und beenden deine Serie nicht.';

  @override
  String get prefUnknownTitle => 'Fragezeichen für fehlende Daten anzeigen';

  @override
  String get prefUnknownDescription =>
      'Tage ohne Daten von tatsächlichen Lücken unterscheiden. Um eine Lücke einzutragen zweimal markieren.';

  @override
  String get youAreNowADeveloper => 'Du bist nun ein Entwickler';

  @override
  String get activityNotFound => 'Für diese Aktion wurde keine App gefunden.';

  @override
  String get prefMidnightDelayTitle =>
      'Verlängere den Tag um ein paar Stunden nach Mitternacht';

  @override
  String get prefMidnightDelayDescription =>
      'Bis 3:00 Uhr warten, bevor ein neuer Tag angezeigt wird. Nützlich, wenn du normalerweise nach Mitternacht schlafen gehst. Benötigt einen Neustart der App.';

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
      other: 'Gewohnheiten geändert',
      one: 'Gewohnheit geändert',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewohnheiten gelöscht',
      one: 'Gewohnheit gelöscht',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewohnheiten archiviert',
      one: 'Gewohnheit archiviert',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewohnheiten wiederhergestellt',
      one: 'Gewohnheit wiederhergestellt',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gewohnheiten löschen?',
      one: 'Gewohnheit löschen?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Die Gewohnheiten werden für immer gelöscht. Dies kann nicht rückgängig gemacht werden.',
      one:
          'Die Gewohnheit wird für immer gelöscht. Dies kann nicht rückgängig gemacht werden.',
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
  String get abstinenceTitle => 'Without a lapse';

  @override
  String abstinenceCleanDaysLabel(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'days without a lapse',
      one: 'day without a lapse',
    );
    return '$_temp0';
  }

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
}
