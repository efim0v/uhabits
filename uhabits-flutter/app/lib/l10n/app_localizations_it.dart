// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class L10nIt extends L10n {
  L10nIt([String locale = 'it']) : super(locale);

  @override
  String get overview => 'Panoramica';

  @override
  String get appName => 'Loop - Tracciatore di Abitudine';

  @override
  String get mainActivityTitle => 'Abitudini';

  @override
  String get actionSettings => 'Impostazioni';

  @override
  String get edit => 'Modifica';

  @override
  String get delete => 'Elimina';

  @override
  String get archive => 'Archivia';

  @override
  String get unarchive => 'Annulla archiviazione';

  @override
  String get addHabit => 'Aggiungi abitudine';

  @override
  String get colorPickerDefaultTitle => 'Cambia colore';

  @override
  String get toastHabitCreated => 'Abitudine creata';

  @override
  String get habitStrength => 'Forza dell\'abitudine';

  @override
  String get history => 'Cronologia';

  @override
  String get clear => 'Annulla';

  @override
  String get reminder => 'Promemoria';

  @override
  String get save => 'Salva';

  @override
  String get streaks => 'Serie';

  @override
  String get noHabitsFound => 'Non hai abitudini attive';

  @override
  String get noHabitsLeftToDo => 'Hai finito tutto per oggi!';

  @override
  String get longPressToToggle => 'Tieni premuto per completare o annullare';

  @override
  String get reminderOff => 'Disabilitato';

  @override
  String get createHabit => 'Crea abitudine';

  @override
  String get editHabit => 'Modifica abitudine';

  @override
  String get check => 'Completa';

  @override
  String get snooze => 'Più tardi';

  @override
  String get introTitle1 => 'Benvenuto';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker ti aiuta a creare e mantenere delle buone abitudini.';

  @override
  String get introTitle2 => 'Aggiungi qualche nuova abitudine';

  @override
  String get introDescription2 =>
      'Ogni giorno, dopo aver portato a termine la tua abitudine, spuntala nell\'app.';

  @override
  String get introTitle4 => 'Segui i tuoi progressi';

  @override
  String get introDescription4 =>
      'Grafici dettagliati ti mostrano come le tue abitudini sono migliorate nel corso del tempo.';

  @override
  String get interval15Minutes => '15 minuti';

  @override
  String get interval30Minutes => '30 minuti';

  @override
  String get interval1Hour => '1 ora';

  @override
  String get interval2Hour => '2 ore';

  @override
  String get interval4Hour => '4 ore';

  @override
  String get interval8Hour => '8 ore';

  @override
  String get interval24Hour => '24 ore';

  @override
  String get intervalAlwaysAsk => 'Chiedi sempre';

  @override
  String get intervalCustom => 'Personalizza...';

  @override
  String get prefToggleTitle => 'Spunta le ripetizioni velocemente';

  @override
  String get prefToggleDescription2 =>
      'Metti i segni di spunta con un tocco rapido invece di tenere premuto.';

  @override
  String get prefRateThisApp => 'Valuta quest\'app su Google Play';

  @override
  String get prefSendFeedback => 'Manda un feedback allo sviluppatore';

  @override
  String get prefViewSourceCode => 'Vedi il codice sorgente su GitHub';

  @override
  String get links => 'Links';

  @override
  String get name => 'Nome';

  @override
  String get settings => 'Impostazioni';

  @override
  String get selectSnoozeDelay => 'Seleziona ritardo posticipo';

  @override
  String get hintTitle => 'Lo sapevi?';

  @override
  String get hintDrag =>
      'Per riordinare le voci, tieni premuto sul nome dell\'abitudine, poi spostala nella posizione corretta.';

  @override
  String get hintLandscape =>
      'Puoi vedere più giorni mettendo il tuo telefono orizzontale.';

  @override
  String get habitNotFound => 'Abitudine cancellata / non trovata';

  @override
  String get weekends => 'Weekend';

  @override
  String get anyWeekday => 'Giorni feriali';

  @override
  String get anyDay => 'Ogni giorno della settimana';

  @override
  String get selectWeekdays => 'Giorni selezionati';

  @override
  String get exportToCsv => 'Esporta i dati come CSV';

  @override
  String get doneLabel => 'Fatto';

  @override
  String get clearLabel => 'Annulla';

  @override
  String get selectHours => 'Ore selezionate';

  @override
  String get selectMinutes => 'Minuti selezionati';

  @override
  String get about => 'Info su';

  @override
  String get translators => 'Traduttori';

  @override
  String get developers => 'Sviluppatori';

  @override
  String versionN(String p1) {
    return 'Versione $p1';
  }

  @override
  String get frequency => 'Frequenza';

  @override
  String get checkmark => 'Spunta';

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
  String get bestStreaks => 'Serie migliori';

  @override
  String get everyDay => 'Ogni giorno';

  @override
  String get everyWeek => 'Ogni settimana';

  @override
  String get help => 'Aiuto & FAQ';

  @override
  String get couldNotExport => 'Esportazione non riuscita.';

  @override
  String get couldNotImport => 'Importazione non riuscita.';

  @override
  String get fileNotRecognized => 'File non riconosciuto.';

  @override
  String get habitsImported => 'Abitudini importate con successo.';

  @override
  String get importData => 'Importa dati';

  @override
  String get exportFullBackup => 'Esporta il backup completo';

  @override
  String get importDataSummary =>
      'Pieno supporto ai backup esportati da questa app, oltre a quelli generati da Tickmate, HabitBull o Rewire. Vedi le FAQ per maggiori informazioni.';

  @override
  String get exportAsCsvSummary =>
      'Genera un file che potrà essere aperto da programmi come Microsoft Excel o OpenOffice Calc. Non potrà essere importato.';

  @override
  String get exportFullBackupSummary =>
      'Genera un file contenente tutti i tuoi dati. Potrà essere importato successivamente.';

  @override
  String get selectPublicBackupFolder =>
      'Seleziona cartella di backup pubblica';

  @override
  String get noPublicBackupFolderSelected => 'Nessuna cartella selezionata';

  @override
  String get bugReportFailed => 'Generazione del bug report fallita';

  @override
  String get generateBugReport => 'Genera bug report';

  @override
  String get troubleshooting => 'Risoluzione dei problemi';

  @override
  String get helpTranslate => 'Aiuta a tradurre questa app';

  @override
  String get nightMode => 'Modalità notte';

  @override
  String get usePureBlack => 'Usa nero puro nella modalità notte';

  @override
  String get pureBlackDescription =>
      'Sostituisce gli sfondi grigi con sfondi neri nella modalità notte. Riduce il consumo di batteria nei dispositivi con schermo AMOLED.';

  @override
  String get interfacePreferences => 'Interfaccia';

  @override
  String get reverseDays => 'Inverti ordine giorni';

  @override
  String get reverseDaysDescription =>
      'Mostra i giorni in ordine inverso nella schermata principale';

  @override
  String get day => 'Giorno';

  @override
  String get week => 'Settimana';

  @override
  String get month => 'Mese';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Anno';

  @override
  String get total => 'Totale';

  @override
  String get yesOrNo => 'Sì o No';

  @override
  String everyXDays(int p1) {
    return 'Ogni $p1 giorni';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Ogni $p1 settimane';
  }

  @override
  String get score => 'Punteggio';

  @override
  String get reminderSound => 'Suono notifica';

  @override
  String get none => 'Nessuno';

  @override
  String get filter => 'Filtra';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Nascondi completati';

  @override
  String get hideEntered => 'Nascondi inserito';

  @override
  String get hideArchived => 'Nascondi archiviati';

  @override
  String get stickyNotifications => 'Notifiche non rimuovibili';

  @override
  String get stickyNotificationsDescription =>
      'Impedisce di poter rimuovere le notifiche.';

  @override
  String get ledNotifications => 'Luce di notifica';

  @override
  String get ledNotificationsDescription =>
      'Mostra una luce lampeggiante per i promemoria. Disponibile solo nei telefoni con luci di notifica a LED.';

  @override
  String get repairDatabase => 'Ripara database';

  @override
  String get databaseRepaired => 'Database recuperato.';

  @override
  String get uncheck => 'Deseleziona';

  @override
  String get toggle => 'Attiva/disattiva';

  @override
  String get action => 'Azione';

  @override
  String get habit => 'Abitudine';

  @override
  String get sort => 'Ordina';

  @override
  String get manually => 'Manualmente';

  @override
  String get byName => 'Per nome';

  @override
  String get byColor => 'Per colore';

  @override
  String get byScore => 'Per punteggio';

  @override
  String get byStatus => 'Per stato';

  @override
  String get export => 'Esporta';

  @override
  String get longPressToEdit => 'Tieni premuto per cambiare il valore';

  @override
  String get value => 'Valore';

  @override
  String get calendar => 'Calendario';

  @override
  String get unit => 'Unità';

  @override
  String get targetType => 'Tipo di destinazione';

  @override
  String get targetTypeAtLeast => 'Almeno';

  @override
  String get targetTypeAtMost => 'Al massimo';

  @override
  String get exampleQuestionBoolean => 'ad es. Ti sei allenato oggi?';

  @override
  String get question => 'Domanda';

  @override
  String get target => 'Obiettivo';

  @override
  String get yes => 'Si';

  @override
  String get no => 'No';

  @override
  String get customizeNotificationSummary =>
      'Cambia suono, vibrazione, luce e altre impostazioni di notifica';

  @override
  String get customizeNotification => 'Personalizza notifiche';

  @override
  String get prefViewPrivacy => 'Visualizza informativa sulla privacy';

  @override
  String get viewAllContributors => 'Visualizza tutti i collaboratori…';

  @override
  String get database => 'Banca dati';

  @override
  String get widgetOpacityTitle => 'Opacità del widget';

  @override
  String get widgetOpacityDescription =>
      'Rende i widget più trasparenti o più opachi nella schermata iniziale.';

  @override
  String get firstDayOfTheWeek => 'Primo giorno della settimana';

  @override
  String get defaultReminderQuestion => 'Hai completato questa abitudine oggi?';

  @override
  String get notes => 'Note';

  @override
  String get exampleNotes => '(Opzionale)';

  @override
  String get yesOrNoExample =>
      'ad es. Ti sei svegliato presto oggi? Hai fatto esercizio? Hai giocato a scacchi?';

  @override
  String get measurable => 'Misurabile';

  @override
  String get measurableExample =>
      'es. Quanti chilometri hai percorso oggi? Quante pagine hai letto?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 volte a settimana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 volte al mese';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 volte in $p2 giorni';
  }

  @override
  String get yesOrNoShortExample => 'ad es. Esercizio';

  @override
  String get color => 'Colore';

  @override
  String get exampleTarget => 'ad es. 15';

  @override
  String get measurableShortExample => 'ad es. Correre';

  @override
  String get measurableQuestionExample =>
      'ad es. Quanti chilometri hai corso oggi?';

  @override
  String get measurableUnitsExample => 'ad es: Chilometri';

  @override
  String get everyMonth => 'Ogni mese';

  @override
  String get validationCannotBeBlank => 'Non può essere lasciato vuoto';

  @override
  String get today => 'Oggi';

  @override
  String get enter => 'Inserisci';

  @override
  String get noHabits => 'Nessuna abitudine trovata';

  @override
  String get noNumericalHabits => 'Nessuna abitudine misurabile trovata';

  @override
  String get noBooleanHabits => 'Nessuna abitudine sì/no trovata';

  @override
  String get increment => 'Incremento';

  @override
  String get decrement => 'Decremento';

  @override
  String get prefSkipTitle => 'Abilita salta giorni';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Attiva/disattiva due volte per aggiungere un salto invece di una spunta. Un salto mantiene il tuo punteggio invariato e non interrompe il tuo punteggio.';

  @override
  String get prefUnknownTitle =>
      'Mostra punti interrogativi per i dati mancanti';

  @override
  String get prefUnknownDescription =>
      'Differenzia i giorni senza dati dagli intervalli effettivi. Per inserire un intervallo, attiva due volte.';

  @override
  String get youAreNowADeveloper => 'Ora sei uno sviluppatore';

  @override
  String get activityNotFound =>
      'Nessuna app disponibile per gestire questa azione';

  @override
  String get prefMidnightDelayTitle =>
      'Prolunga il giorno di alcune ore dopo la mezzanotte';

  @override
  String get prefMidnightDelayDescription =>
      'Attendere fino alle 3:00 per mostrare il nuovo giorno. Utile se solitamente vai a dormire dopo mezzanotte. È necessario riavviare l\'app.';

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
      other: 'Abitudini modificate',
      one: 'Abitudine modificata',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abitudini eliminate',
      one: 'Abitudine eliminata',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abitudini archiviate',
      one: 'Abitudine archiviata',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Abitudini non archiviate',
      one: 'Abitudine non archiviata',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminare le abitudini?',
      one: 'Eliminare l\'abitudine?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Le abitudini verranno eliminate definitivamente. Questa azione non può essere annullata.',
      one:
          'L\'abitudine verrà eliminata definitivamente. Questa azione non può essere annullata.',
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
