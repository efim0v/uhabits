// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class L10nCa extends L10n {
  L10nCa([String locale = 'ca']) : super(locale);

  @override
  String get overview => 'Visió general';

  @override
  String get appName => 'Loop - Hàbit Rastrejador';

  @override
  String get mainActivityTitle => 'Hàbits';

  @override
  String get actionSettings => 'Configuració';

  @override
  String get edit => 'Editar';

  @override
  String get delete => 'Esborrar';

  @override
  String get archive => 'Arxivar';

  @override
  String get unarchive => 'Treure de l\'arxiu';

  @override
  String get addHabit => 'Afegir hàbit';

  @override
  String get colorPickerDefaultTitle => 'Canviar el color';

  @override
  String get toastHabitCreated => 'Hàbit creat.';

  @override
  String get habitStrength => 'Fortalesa de l\'hàbit';

  @override
  String get history => 'Història';

  @override
  String get clear => 'Netejar';

  @override
  String get reminder => 'Recordatori';

  @override
  String get save => 'Desar';

  @override
  String get streaks => 'Ratxa';

  @override
  String get noHabitsFound => 'No tens hàbits actius';

  @override
  String get noHabitsLeftToDo => 'Ja heu acabat per avui!';

  @override
  String get longPressToToggle => 'Prem i manté per a marcar o desmarcar';

  @override
  String get reminderOff => 'Desactivat';

  @override
  String get createHabit => 'Crear hàbit';

  @override
  String get editHabit => 'Editar hàbit';

  @override
  String get check => 'Revisar';

  @override
  String get snooze => 'Més tard';

  @override
  String get introTitle1 => 'Benvingut';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker t\'ajuda a crear i mantenir bons hàbits';

  @override
  String get introTitle2 => 'Crear alguns hàbits nous';

  @override
  String get introDescription2 =>
      'Cada dia, després de complir el teu hàbit, posa una marca amb l\'aplicació.';

  @override
  String get introTitle4 => 'Segueix el teu progrès';

  @override
  String get introDescription4 =>
      'Els gràfics detallats et mostren com han mirollat els teus hàbits al llarg del temps';

  @override
  String get interval15Minutes => '15 minuts';

  @override
  String get interval30Minutes => '30 minuts';

  @override
  String get interval1Hour => '1 hora';

  @override
  String get interval2Hour => '2 hores';

  @override
  String get interval4Hour => '4 hores';

  @override
  String get interval8Hour => '8 hores';

  @override
  String get interval24Hour => '24 hores';

  @override
  String get intervalAlwaysAsk => 'Pregunta sempre';

  @override
  String get intervalCustom => 'Personalitza...';

  @override
  String get prefToggleTitle => 'Activar/desactivar repeticions prement curt';

  @override
  String get prefToggleDescription2 =>
      'Posa les marques de verificació amb un sol toc en lloc de prémer';

  @override
  String get prefRateThisApp => 'Valora aquesta app a Google Play';

  @override
  String get prefSendFeedback => 'Enviar resposta al desenvolupador';

  @override
  String get prefViewSourceCode => 'Veure codi font a Github';

  @override
  String get links => 'Enllaços';

  @override
  String get name => 'Nom';

  @override
  String get settings => 'Ajustaments';

  @override
  String get selectSnoozeDelay => 'Selecciona el retard de l\'endarreriment';

  @override
  String get hintTitle => 'Ho sabies?';

  @override
  String get hintDrag =>
      'Per a ordenar les entrades, prem i mantè sobre el nom de l\'hàbit, després arrossega\'l al lloc correcte.';

  @override
  String get hintLandscape =>
      'Pots veure més dies posant el teu telèfon en orientació apaisada.';

  @override
  String get habitNotFound => 'Hàbit suprimit / no trobat';

  @override
  String get weekends => 'Caps de setmana';

  @override
  String get anyWeekday => 'Dilluns a divendres';

  @override
  String get anyDay => 'Qualsevol dia de la setmana';

  @override
  String get selectWeekdays => 'Selecciona els dies';

  @override
  String get exportToCsv => 'Exportar a CSV';

  @override
  String get doneLabel => 'Fet';

  @override
  String get clearLabel => 'Treure';

  @override
  String get selectHours => 'Selecciona les hores';

  @override
  String get selectMinutes => 'Selecciona els minuts';

  @override
  String get about => 'En quant a';

  @override
  String get translators => 'Traductors';

  @override
  String get developers => 'Desenvolupadors';

  @override
  String versionN(String p1) {
    return 'Versió $p1';
  }

  @override
  String get frequency => 'Freqüència';

  @override
  String get checkmark => 'Marca';

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
  String get bestStreaks => 'Millors ratxes';

  @override
  String get everyDay => 'Cada dia';

  @override
  String get everyWeek => 'Cada setmana';

  @override
  String get help => 'Ajuda i Preguntes Freqüents';

  @override
  String get couldNotExport => 'Error exportant dades.';

  @override
  String get couldNotImport => 'Error important dades.';

  @override
  String get fileNotRecognized => 'Fitxer no reconegut.';

  @override
  String get habitsImported => 'Hàbits importats correctament.';

  @override
  String get importData => 'Importar dades';

  @override
  String get exportFullBackup => 'Exportar còpia de seguretat sencera';

  @override
  String get importDataSummary =>
      'Suporta còpies de seguretat exportades per aquesta app, també fitxers generats per Tickmate, HabitBull o Rewire. Mira les Preguntes Freqüents per a més informació.';

  @override
  String get exportAsCsvSummary =>
      'Genera fitxers que poden ser oberts per programari de fulles de càlcul, com ara Microsoft Excel o OpenOffice Calc. Aquest fitxer no pot tornar-se a importar.';

  @override
  String get exportFullBackupSummary =>
      'Genera un fitxer que contè totes les teves dades. Aquest fitxer pot tornar-se a importar.';

  @override
  String get selectPublicBackupFolder =>
      'Seleccioneu la carpeta pública de còpia de seguretat';

  @override
  String get noPublicBackupFolderSelected => 'No s\'ha seleccionat cap carpeta';

  @override
  String get bugReportFailed =>
      'Ha fallat la generació de l\'informe d\'error.';

  @override
  String get generateBugReport => 'Generar informe d\'error';

  @override
  String get troubleshooting => 'Resolució de problemes';

  @override
  String get helpTranslate => 'Ajuda a traduïr aquesta app';

  @override
  String get nightMode => 'Mode nocturn';

  @override
  String get usePureBlack => 'Utilitzar negre pur en el mode nocturn';

  @override
  String get pureBlackDescription =>
      'Reemplaça fons grisos per negre pur en el mode nocturn. Redueix consum de bateria en telèfons amb pantalla AMOLED.';

  @override
  String get interfacePreferences => 'Interfície';

  @override
  String get reverseDays => 'Ordre invers de dies';

  @override
  String get reverseDaysDescription =>
      'Mostra els dies en ordre invers en la pantalla principal';

  @override
  String get day => 'Dia';

  @override
  String get week => 'Setmana';

  @override
  String get month => 'Mes';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Any';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Sí o No';

  @override
  String everyXDays(int p1) {
    return 'Cada $p1 dies';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Cada $p1 setmanes';
  }

  @override
  String get score => 'Puntuació';

  @override
  String get reminderSound => 'So de recordatori';

  @override
  String get none => 'Cap';

  @override
  String get filter => 'Filtre';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Amaga completat';

  @override
  String get hideEntered => 'Amagar introduït';

  @override
  String get hideArchived => 'Amaga arxivades';

  @override
  String get stickyNotifications => 'Fer les notificacions enganxós';

  @override
  String get stickyNotificationsDescription =>
      'Evita les notificacions de ser pispat lluny.';

  @override
  String get ledNotifications => 'Llum de notificació';

  @override
  String get ledNotificationsDescription =>
      'Mostra una llum parpallejant per als recordatoris. Només disponible en telèfons amb llums de notificació LED.';

  @override
  String get repairDatabase => 'Base de dades de reparació';

  @override
  String get databaseRepaired => 'Reparar base de dades.';

  @override
  String get uncheck => 'Desmarca';

  @override
  String get toggle => 'Canvia';

  @override
  String get action => 'Acció';

  @override
  String get habit => 'Hàbit';

  @override
  String get sort => 'Ordenar';

  @override
  String get manually => 'Manualment';

  @override
  String get byName => 'Per nom';

  @override
  String get byColor => 'Pel color';

  @override
  String get byScore => 'Per marcador';

  @override
  String get byStatus => 'Per estat';

  @override
  String get export => 'Exportar';

  @override
  String get longPressToEdit => 'Prémer i mantenir per a canviar el valor';

  @override
  String get value => 'Valor';

  @override
  String get calendar => 'Calendari';

  @override
  String get unit => 'Unitat';

  @override
  String get targetType => 'Tipus objectiu';

  @override
  String get targetTypeAtLeast => 'Al menys';

  @override
  String get targetTypeAtMost => 'At most';

  @override
  String get exampleQuestionBoolean => 'p.e. Has fet exercici avui?';

  @override
  String get question => 'Pregunta';

  @override
  String get target => 'Objectiu';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get customizeNotificationSummary =>
      'Canviar so, vibració, llum i altres ajustaments de notificacions';

  @override
  String get customizeNotification => 'Personalitzar les notificacions';

  @override
  String get prefViewPrivacy => 'Veure la política de privadesa';

  @override
  String get viewAllContributors => 'Veure tots els col·laboradors…';

  @override
  String get database => 'Base de dades';

  @override
  String get widgetOpacityTitle => 'Opacitat del giny';

  @override
  String get widgetOpacityDescription =>
      'Fa que els ginys siguin més transparents o més opacs a la pantalla d\'inici.';

  @override
  String get firstDayOfTheWeek => 'Primer dia de la setmana';

  @override
  String get defaultReminderQuestion => 'Has completat aquest hàbit avui?';

  @override
  String get notes => 'Notes';

  @override
  String get exampleNotes => 'Opcional';

  @override
  String get yesOrNoExample =>
      'Per exemple, us heu despertat aviat? Heu fet exercici? Heu jugat a escacs?';

  @override
  String get measurable => 'Mesurable';

  @override
  String get measurableExample =>
      'p.e. Quants quilòmetres has fet hui? Quantes pàgines has llegit?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 vegades per setmana';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 vegades al mes';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 vegades en $p2 dies';
  }

  @override
  String get yesOrNoShortExample => 'Ex. Exercici';

  @override
  String get color => 'Color';

  @override
  String get exampleTarget => 'ex. 15';

  @override
  String get measurableShortExample => 'Per exemple: córrer';

  @override
  String get measurableQuestionExample =>
      'Per exemple, quants quilòmetres heu recorregut avui?';

  @override
  String get measurableUnitsExample => 'per exemple, quilòmetres';

  @override
  String get everyMonth => 'Cada mes';

  @override
  String get validationCannotBeBlank => 'No es pot deixar en blanc';

  @override
  String get today => 'Avui';

  @override
  String get enter => 'Introduïr';

  @override
  String get noHabits => 'No s\'han trobat hàbits.';

  @override
  String get noNumericalHabits => 'No s\'han trobat hàbits mesurables';

  @override
  String get noBooleanHabits => 'No s\'han trobat hàbits de sí o no';

  @override
  String get increment => 'Increment';

  @override
  String get decrement => 'Disminueix';

  @override
  String get prefSkipTitle => 'Activa omitir dies';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Toca dues vegades per a afegir una omissió en compte d\'una marca de verificació. Les omissions mantenen la teua puntuació sense canvis i no trenquen la ratxa.';

  @override
  String get prefUnknownTitle =>
      'Mostra signes d\'interrogació per a les dades que falten';

  @override
  String get prefUnknownDescription =>
      'Diferenciar els dies sense dades dels lapses reals. Per introduir un lapse, canvia dues vegades.';

  @override
  String get youAreNowADeveloper => 'Ara eres un desenvolupador';

  @override
  String get activityNotFound =>
      'No s\'ha trobat cap aplicació per a gestionar aquesta acció';

  @override
  String get prefMidnightDelayTitle =>
      'Ampliar el dia unes hores després de la mitjanit';

  @override
  String get prefMidnightDelayDescription =>
      'Esperar fins a les 3:00 per mostrar un nou dia. Útil si normalment vas a dormir després de la mitjanit. Requereix el reinici de l\'aplicació.';

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
      other: 'Hàbit modificat.',
      one: 'Hàbit modificat.',
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
      other: 'Hàbit no arxivat',
      one: 'Hàbit no arxivat',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Esborrar hàbit',
      one: 'Esborrar hàbit',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Els hàbits seran esborrats permanentment. Aquesta acció no es pot desfer.',
      one:
          'L\' hàbit serà esborrat permanentment. Aquesta acció no es pot desfer.',
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
