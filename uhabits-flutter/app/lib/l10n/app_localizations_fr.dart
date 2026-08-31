// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class L10nFr extends L10n {
  L10nFr([String locale = 'fr']) : super(locale);

  @override
  String get overview => 'Vue d\'ensemble';

  @override
  String get appName => 'Loop - Suivi d\'habitudes';

  @override
  String get mainActivityTitle => 'Habitudes';

  @override
  String get actionSettings => 'Paramètres';

  @override
  String get edit => 'Modifier';

  @override
  String get delete => 'Supprimer';

  @override
  String get archive => 'Archiver';

  @override
  String get unarchive => 'Désarchiver';

  @override
  String get addHabit => 'Ajouter une habitude';

  @override
  String get colorPickerDefaultTitle => 'Changer la couleur';

  @override
  String get toastHabitCreated => 'Habitude créée';

  @override
  String get habitStrength => 'Force de l\'habitude';

  @override
  String get history => 'Historique';

  @override
  String get clear => 'Supprimer';

  @override
  String get reminder => 'Rappel';

  @override
  String get save => 'Sauvegarder';

  @override
  String get streaks => 'Séries';

  @override
  String get noHabitsFound => 'Vous n\'avez pas d\'habitudes actives';

  @override
  String get noHabitsLeftToDo =>
      'Vous avez fait toutes vos habitudes d\'aujourd\'hui !';

  @override
  String get longPressToToggle => 'Appuyez longtemps pour cocher ou décocher';

  @override
  String get reminderOff => 'Aucun';

  @override
  String get createHabit => 'Créer une habitude';

  @override
  String get editHabit => 'Modifier l\'habitude';

  @override
  String get check => 'Cocher';

  @override
  String get snooze => 'Plus tard';

  @override
  String get introTitle1 => 'Bienvenue';

  @override
  String get introDescription1 =>
      'Loop - Suivi d\'habitudes vous aide à créer et maintenir de bonnes habitudes.';

  @override
  String get introTitle2 => 'Créez de nouvelles habitudes';

  @override
  String get introDescription2 =>
      'Chaque jour, après avoir réalisé votre habitude, cochez-la sur l\'application.';

  @override
  String get introTitle4 => 'Suivez votre progrès';

  @override
  String get introDescription4 =>
      'Des graphiques détaillés vous montrent comment vos habitudes évoluent au fil du temps.';

  @override
  String get interval15Minutes => '15 minutes';

  @override
  String get interval30Minutes => '30 minutes';

  @override
  String get interval1Hour => '1 heure';

  @override
  String get interval2Hour => '2 heures';

  @override
  String get interval4Hour => '4 heures';

  @override
  String get interval8Hour => '8 heures';

  @override
  String get interval24Hour => '24 heures';

  @override
  String get intervalAlwaysAsk => 'Toujours demander';

  @override
  String get intervalCustom => 'Personnaliser...';

  @override
  String get prefToggleTitle => 'Valider l\'habitude avec un appui court';

  @override
  String get prefToggleDescription2 =>
      'Cochez les cases d\'un simple appui au lieu de les maintenir';

  @override
  String get prefRateThisApp => 'Notez cette app sur le Google Play Store';

  @override
  String get prefSendFeedback => 'Envoyez un avis au développeur';

  @override
  String get prefViewSourceCode => 'Voir le code source sur GitHub';

  @override
  String get links => 'Liens';

  @override
  String get name => 'Nom';

  @override
  String get settings => 'Paramètres';

  @override
  String get selectSnoozeDelay => 'Définir le délai de répétition';

  @override
  String get hintTitle => 'Le saviez-vous ?';

  @override
  String get hintDrag =>
      'Pour réordonner les habitudes, faites un appui long sur le nom de l\'habitude et placez-la à la bonne place.';

  @override
  String get hintLandscape =>
      'Vous pouvez voir plus de jours en mettant votre téléphone en mode paysage.';

  @override
  String get habitNotFound => 'Habitude supprimée / introuvable';

  @override
  String get weekends => 'Weekends';

  @override
  String get anyWeekday => 'Du lundi au vendredi';

  @override
  String get anyDay => 'N\'importe quel jour';

  @override
  String get selectWeekdays => 'Sélectionner des jours';

  @override
  String get exportToCsv => 'Exporter les données dans un fichier CSV';

  @override
  String get doneLabel => 'Fait';

  @override
  String get clearLabel => 'Supprimer';

  @override
  String get selectHours => 'Sélectionner les heures';

  @override
  String get selectMinutes => 'Sélectionner les minutes';

  @override
  String get about => 'À propos';

  @override
  String get translators => 'Traducteurs';

  @override
  String get developers => 'Développeurs';

  @override
  String versionN(String p1) {
    return 'Version $p1';
  }

  @override
  String get frequency => 'Fréquence';

  @override
  String get checkmark => 'Case à cocher';

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
  String get bestStreaks => 'Meilleures séries';

  @override
  String get everyDay => 'Tous les jours';

  @override
  String get everyWeek => 'Toutes les semaines';

  @override
  String get help => 'Aide & FAQ';

  @override
  String get couldNotExport => 'Export des données échoué.';

  @override
  String get couldNotImport => 'Import des données échoué.';

  @override
  String get fileNotRecognized => 'Fichier non reconnu';

  @override
  String get habitsImported => 'Habitudes importées avec succès';

  @override
  String get importData => 'Importer des données';

  @override
  String get exportFullBackup => 'Exporter une sauvegarde complète';

  @override
  String get importDataSummary =>
      'Supporte les sauvegardes complètes générées par cette application, ainsi que les fichiers Tickmate, HabitBull et Rewire. Voir la FAQ pour plus d\'informations.';

  @override
  String get exportAsCsvSummary =>
      'Génère des fichiers pouvant être ouverts par des tableurs comme Microsoft Excel ou LibreOffice Calc. Ce fichier ne peut pas être réimporté.';

  @override
  String get exportFullBackupSummary =>
      'Génère un fichier contenant toutes vos données. Ce fichier peut être réimporté.';

  @override
  String get selectPublicBackupFolder =>
      'Sélectionner le dossier de sauvegarde public';

  @override
  String get noPublicBackupFolderSelected => 'Aucun dossier sélectionné';

  @override
  String get bugReportFailed => 'La génération du rapport de bug a échouée.';

  @override
  String get generateBugReport => 'Générer un rapport de bug.';

  @override
  String get troubleshooting => 'Résolution de problèmes';

  @override
  String get helpTranslate => 'Aider à traduire cette application';

  @override
  String get nightMode => 'Mode Nuit';

  @override
  String get usePureBlack => 'Utiliser un noir pur dans le mode nuit';

  @override
  String get pureBlackDescription =>
      'Remplace le fond gris par un noir pur dans le mode nuit ; cela réduit l’usage de la batterie des appareils ayant un écran AMOLED.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Inverser l\'ordre des jours';

  @override
  String get reverseDaysDescription =>
      'Montrer les jours dans l\'ordre inversé sur l\'écran principal';

  @override
  String get day => 'Jour';

  @override
  String get week => 'Semaine';

  @override
  String get month => 'Mois';

  @override
  String get quarter => 'Trimestre';

  @override
  String get year => 'Année';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Oui ou Non';

  @override
  String everyXDays(int p1) {
    return 'Tous les $p1 jours';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Toutes les $p1 semaines';
  }

  @override
  String get score => 'Score';

  @override
  String get reminderSound => 'Son de rappel';

  @override
  String get none => 'Aucun';

  @override
  String get filter => 'Filtre';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Cacher les habitudes complétées';

  @override
  String get hideEntered => 'Cacher les entrées';

  @override
  String get hideArchived => 'Cacher les habitudes archivées';

  @override
  String get stickyNotifications => 'Rendre les notifications persistantes';

  @override
  String get stickyNotificationsDescription =>
      'Évite que les notifications ne soient enlevées.';

  @override
  String get ledNotifications => 'Notification de lumière led';

  @override
  String get ledNotificationsDescription =>
      'Affiche une lumière clignotante pour les rappels. Uniquement disponible dans les téléphones avec lumière de notification LED.';

  @override
  String get repairDatabase => 'Réparer la base de données';

  @override
  String get databaseRepaired => 'Base de données réparée.';

  @override
  String get uncheck => 'Décocher';

  @override
  String get toggle => 'Basculer';

  @override
  String get action => 'Action';

  @override
  String get habit => 'Habitude';

  @override
  String get sort => 'Trier';

  @override
  String get manually => 'Manuellement';

  @override
  String get byName => 'Par nom';

  @override
  String get byColor => 'Par couleur';

  @override
  String get byScore => 'Par score';

  @override
  String get byStatus => 'Par statut';

  @override
  String get export => 'Exporter';

  @override
  String get longPressToEdit => 'Appuyez et maintenez pour changer la valeur';

  @override
  String get value => 'Valeur';

  @override
  String get calendar => 'Calendrier';

  @override
  String get unit => 'Unité';

  @override
  String get targetType => 'Type d\'objectif';

  @override
  String get targetTypeAtLeast => 'Au moins';

  @override
  String get targetTypeAtMost => 'Au plus';

  @override
  String get exampleQuestionBoolean =>
      'Par ex., avez-vous fait de l\'exercice aujourd\'hui?';

  @override
  String get question => 'Question';

  @override
  String get target => 'Cible';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get customizeNotificationSummary =>
      'Modifier le son, les vibrations, la lumière et d\'autres paramètres de notification';

  @override
  String get customizeNotification => 'Personnaliser les notifications';

  @override
  String get prefViewPrivacy => 'Voir la politique de confidentialité';

  @override
  String get viewAllContributors => 'Voir tous les contributeurs…';

  @override
  String get database => 'Base de données';

  @override
  String get widgetOpacityTitle => 'Opacité des widgets';

  @override
  String get widgetOpacityDescription =>
      'Rend les widgets plus transparents ou plus opaques sur votre écran d\'accueil.';

  @override
  String get firstDayOfTheWeek => 'Premier jour de la semaine';

  @override
  String get defaultReminderQuestion =>
      'Avez-vous réalisé cette habitude, aujourd\'hui ?';

  @override
  String get notes => 'Remarques';

  @override
  String get exampleNotes => '(Facultatif)';

  @override
  String get yesOrNoExample =>
      'Par exemple, vous êtes-vous réveillé tôt aujourd\'hui ? Avez-vous fait de l\'exercice ? Avez-vous joué aux échecs ?';

  @override
  String get measurable => 'Quantifiable';

  @override
  String get measurableExample =>
      'Par exemple : Quelle distance avez vous parcouru aujourd\'hui ? \nCombien de pages avez-vous lu ?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 fois par semaine';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 fois par mois';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 fois en $p2 jours';
  }

  @override
  String get yesOrNoShortExample => 'Par ex, Entrainement';

  @override
  String get color => 'Couleur';

  @override
  String get exampleTarget => 'Par ex, 15';

  @override
  String get measurableShortExample => 'Par ex, Courir';

  @override
  String get measurableQuestionExample =>
      'Par ex, Combien de km avez-vous couru aujourd\'hui?';

  @override
  String get measurableUnitsExample => 'Par ex, km';

  @override
  String get everyMonth => 'Tous les mois';

  @override
  String get validationCannotBeBlank => 'Ne peut pas être vide';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get enter => 'Inscrire';

  @override
  String get noHabits => 'Aucune habitude trouvée :(';

  @override
  String get noNumericalHabits => 'Aucune habitude quantifiable trouvée';

  @override
  String get noBooleanHabits => 'Aucune habitude binaire trouvée';

  @override
  String get increment => 'Augmenter';

  @override
  String get decrement => 'Diminuer';

  @override
  String get prefSkipTitle => 'Pouvoir passer des jours';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Appuyer deux fois pour passer un jour au lieu de valider. Passer des jours ne change pas votre score et ne brise pas votre série.';

  @override
  String get prefUnknownTitle =>
      'Afficher des points d\'interrogations pour les données manquantes';

  @override
  String get prefUnknownDescription =>
      'Différentié les jours sans donnée des jours sans avoir fait les habitudes. Pour passer un jour, appuyez deux fois longtemps au lieu d\'une seul fois.';

  @override
  String get youAreNowADeveloper => 'Vous êtes désormais un développeur !';

  @override
  String get activityNotFound =>
      'Aucune application trouvée pour faire cette action';

  @override
  String get prefMidnightDelayTitle =>
      'Prolonger les jours de quelques heures après minuit';

  @override
  String get prefMidnightDelayDescription =>
      'Attendre jusqu\'à trois heures du matin pour changer de jour. Très utile si vous avez l\'habitude d\'aller dormir après minuit. (Redémarrage nécessaire)';

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
      other: 'Habitudes modifiées',
      one: 'Habitude modifiée',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habitudes supprimées',
      one: 'Habitude supprimée',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habitudes archivées',
      one: 'Habitude archivée',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Habitudes désarchivées',
      one: 'Habitude désarchivée',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer ces habitudes ?',
      one: 'Supprimer cette habitude ?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les habitudes vont être supprimées définitivements. Cette action ne peut pas être annulée.',
      one:
          'L\'habitude va être supprimée définitivement. Cette action ne peut pas être annulée.',
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
