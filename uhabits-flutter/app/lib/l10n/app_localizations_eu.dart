// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Basque (`eu`).
class L10nEu extends L10n {
  L10nEu([String locale = 'eu']) : super(locale);

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Ohiturak';

  @override
  String get actionSettings => 'Ezarpenak';

  @override
  String get edit => 'Editatu';

  @override
  String get delete => 'Ezabatu';

  @override
  String get archive => 'Artxibatu';

  @override
  String get unarchive => 'Desartxibatu';

  @override
  String get addHabit => 'Gehitu ohitura';

  @override
  String get colorPickerDefaultTitle => 'Kolorea aldatu';

  @override
  String get toastHabitCreated => 'Ohitura sortu da';

  @override
  String get habitStrength => 'Ohituraren indarra';

  @override
  String get history => 'Historia';

  @override
  String get clear => 'Garbitu';

  @override
  String get reminder => 'Oroigarria';

  @override
  String get save => 'Gorde';

  @override
  String get streaks => 'Boladak';

  @override
  String get noHabitsFound => 'Ez duzu ohitura aktiborik';

  @override
  String get noHabitsLeftToDo => 'Gaurkoz amaitu duzu!';

  @override
  String get longPressToToggle =>
      'Sakatu eta mantendu markatu edo desmarkatzeko';

  @override
  String get reminderOff => 'Itzalita';

  @override
  String get createHabit => 'Ohitura sortu';

  @override
  String get editHabit => 'Ohitura editatu';

  @override
  String get check => 'Markatu';

  @override
  String get snooze => 'Geroago';

  @override
  String get introTitle1 => 'Ongi etorri';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker-ek ohitura onak hartzen eta mantentzen laguntzen dizu.';

  @override
  String get introTitle2 => 'Sor itzazu ohitura berri batzuk';

  @override
  String get introDescription2 =>
      'Egunero, zure ohitura egin ostean, jarri ezazu egiaztatze marka bat aplikazioan.';

  @override
  String get introTitle4 => 'Jarrai ezazu zure aurrerapena';

  @override
  String get introDescription4 =>
      'Grafiko zehatzen bitartez denboran zehar zure ohiturak nola hobetu diren ikus ditzakezu';

  @override
  String get interval15Minutes => '15 minutu';

  @override
  String get interval30Minutes => '30 minutu';

  @override
  String get interval1Hour => 'Ordu 1';

  @override
  String get interval2Hour => '2 ordu';

  @override
  String get interval4Hour => '4 ordu';

  @override
  String get interval8Hour => '8 ordu';

  @override
  String get interval24Hour => '24 ordu';

  @override
  String get intervalAlwaysAsk => 'Galdetu beti';

  @override
  String get intervalCustom => 'Pertsonalizatua...';

  @override
  String get prefToggleTitle => 'Ukitze laburrarekin markatu';

  @override
  String get prefToggleDescription2 =>
      'Jarri kontrol-markak ukitu bakar batekin sakatu eta eutsi beharrean.';

  @override
  String get prefRateThisApp => 'Aplikazio hau Google Playen puntuatu';

  @override
  String get prefSendFeedback => 'Zure iritzia garatzaileari bidali';

  @override
  String get prefViewSourceCode => 'Iturburu kodea GitHuben ikusi';

  @override
  String get links => 'Loturak';

  @override
  String get name => 'Izena';

  @override
  String get settings => 'Ezarpenak';

  @override
  String get selectSnoozeDelay => 'Aukeratu atzerapen denbora';

  @override
  String get hintTitle => 'Ba al zenekien?';

  @override
  String get hintDrag =>
      'Sarrerak berrantolatzeko, sakatu eta mantendu ohituraren izena, ondoren mugi ezazu leku aproposera.';

  @override
  String get hintLandscape =>
      'Egun gehiago ikus ditzakezu zure gailua paisai moduan jarriz.';

  @override
  String get habitNotFound => 'Ohitura ezabatua / ez aurkitua';

  @override
  String get weekends => 'Asteburuak';

  @override
  String get anyWeekday => 'Astelehenetik ostiralera';

  @override
  String get anyDay => 'Astearen edozen egun';

  @override
  String get selectWeekdays => 'Egunak hautatu';

  @override
  String get exportToCsv => 'CSV bezala esportatu';

  @override
  String get doneLabel => 'Eginda';

  @override
  String get clearLabel => 'Garbitu';

  @override
  String get selectHours => 'Orduak hautatu';

  @override
  String get selectMinutes => 'Minutuak hautatu';

  @override
  String get about => 'Honi buruz';

  @override
  String get translators => 'Itzultzaileak';

  @override
  String get developers => 'Garatzaileak';

  @override
  String versionN(String p1) {
    return '$p1 bertsioa';
  }

  @override
  String get frequency => 'Maiztasuna';

  @override
  String get checkmark => 'Egiaztatze marka';

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
  String get bestStreaks => 'Bolada onenak';

  @override
  String get everyDay => 'Egunero';

  @override
  String get everyWeek => 'Astero';

  @override
  String get help => 'Laguntza eta ohiko galderak';

  @override
  String get couldNotExport => 'Huts datuak esportatzerakoan.';

  @override
  String get couldNotImport => 'Huts datuak inportatzerakoan.';

  @override
  String get fileNotRecognized => 'Fitxategi ezezaguna.';

  @override
  String get habitsImported => 'Ohiturak ondo inportatu dira.';

  @override
  String get importData => 'Datuak inportatu';

  @override
  String get exportFullBackup => 'Babes kopia osoa esportatu';

  @override
  String get importDataSummary =>
      'Aplikazio honek esportatutako babes kopia osoak onartzen dira, baita Tickmate, HabitBull edo Rewirek sortutako fitxategiak ere. Ikusi ohito galderak informazio gehiago lortzeko.';

  @override
  String get exportAsCsvSummary =>
      'Microsoft Excel edo OpenOffice Calc bezalako kalkulu orrietarako softwareak ireki dezaketen fitxategiak sortzen ditu. Fitxategi hau ezin da berriz inportatu.';

  @override
  String get exportFullBackupSummary =>
      'Zure datu guztiak dituen fitxategi bat sortzen du. Fitxategi hau ezin da berriz inportatu.';

  @override
  String get selectPublicBackupFolder =>
      'Hautatu babeskopia publikoaren karpeta';

  @override
  String get noPublicBackupFolderSelected => 'Ez da karpetarik hautatu';

  @override
  String get bugReportFailed => 'Huts akats txostena sortzerakoan.';

  @override
  String get generateBugReport => 'Akats txostena sortu';

  @override
  String get troubleshooting => 'Arazoen konponketa';

  @override
  String get helpTranslate => 'Lagundu aplikazio hau itzultzen';

  @override
  String get nightMode => 'Azal iluna';

  @override
  String get usePureBlack => 'erabili beltz hutsa azal ilunean';

  @override
  String get pureBlackDescription =>
      'Atzeko plano grisak beltz hutsez aldatzen ditu azal ilunean. Bateriaren erabilera gutxitzen du AMOLED duten gailuetan.';

  @override
  String get interfacePreferences => 'Interfazea';

  @override
  String get reverseDays => 'Egunak atzekoz aurrera ordenatu';

  @override
  String get reverseDaysDescription =>
      'Pantaila nagusian egunak atzekoz aurrera ikusi';

  @override
  String get day => 'Eguna';

  @override
  String get week => 'Astea';

  @override
  String get month => 'Hilabetea';

  @override
  String get quarter => 'Hiruhilekoa';

  @override
  String get year => 'Urtea';

  @override
  String get total => 'Guztira';

  @override
  String get yesOrNo => 'Bai ala ez';

  @override
  String everyXDays(int p1) {
    return '$p1 egunero';
  }

  @override
  String everyXWeeks(int p1) {
    return '$p1 astero';
  }

  @override
  String get score => 'Lorpena';

  @override
  String get reminderSound => 'Oroigarriaren soinua';

  @override
  String get none => 'Bat ere ez';

  @override
  String get filter => 'Iragazkia';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Ezkutatu lortutakoak';

  @override
  String get hideEntered => 'Ezkutatu betetakoak';

  @override
  String get hideArchived => 'Ezkutatu artxibatutakoak';

  @override
  String get stickyNotifications => 'Jakinarazpenak itsaskorrak bihurtu';

  @override
  String get stickyNotificationsDescription =>
      'Jakinarazpenak keinu batez ezabatzea sahiesten du.';

  @override
  String get ledNotifications => 'Jakinarazpen argia';

  @override
  String get ledNotificationsDescription =>
      'Oroigarri gisa argia keinuka erakusten du. Jakinarazpen LED argiak dituzten telefonoetan bakarrik dago erabilgarri.';

  @override
  String get repairDatabase => 'Datu basea konpondu';

  @override
  String get databaseRepaired => 'Datu basea konpondu da.';

  @override
  String get uncheck => 'Desmarkatu';

  @override
  String get toggle => 'Aldatu';

  @override
  String get action => 'Ekintza';

  @override
  String get habit => 'Ohitura';

  @override
  String get sort => 'Ordenatu';

  @override
  String get manually => 'Eskuz';

  @override
  String get byName => 'Izenaren arabera';

  @override
  String get byColor => 'Kolorearen arabera';

  @override
  String get byScore => 'Puntuen arabera';

  @override
  String get byStatus => 'Egoeraren arabera';

  @override
  String get export => 'Esportatu';

  @override
  String get longPressToEdit => 'Sakatu luze balioa aldatzeko';

  @override
  String get value => 'Balioa';

  @override
  String get calendar => 'Egutegia';

  @override
  String get unit => 'Unitatea';

  @override
  String get targetType => 'Helburu mota';

  @override
  String get targetTypeAtLeast => 'Gutxienez';

  @override
  String get targetTypeAtMost => 'Gehienez';

  @override
  String get exampleQuestionBoolean => 'adib. ariketa egin al duzu gaur?';

  @override
  String get question => 'Galdera';

  @override
  String get target => 'Helburua';

  @override
  String get yes => 'Bai';

  @override
  String get no => 'Ez';

  @override
  String get customizeNotificationSummary =>
      'Aldatu soinua, bibrazioa, argia eta bestelako jakinarazpen-ezarpen';

  @override
  String get customizeNotification => 'Pertsonalizatu jakinarazpenak';

  @override
  String get prefViewPrivacy => 'Ikusi pribatutasun politika';

  @override
  String get viewAllContributors => 'Ikusi laguntzaile guztiak&#8230;';

  @override
  String get database => 'Datu-basea';

  @override
  String get widgetOpacityTitle => 'Trepetaren opakutasuna';

  @override
  String get widgetOpacityDescription =>
      'Trepetak gardenagoak edo opakoagoak bihurtzen ditu hasierako pantailan.';

  @override
  String get firstDayOfTheWeek => 'Asteko lehen eguna';

  @override
  String get defaultReminderQuestion => 'Ohitura hau bete al duzu gaur?';

  @override
  String get notes => 'Oharrak';

  @override
  String get exampleNotes => '(Aukerazkoa)';

  @override
  String get yesOrNoExample =>
      'adib. Gaur goiz esnatu zara? Ariketa fisikoa egin al duzu? Xakean jolastu al duzu?';

  @override
  String get measurable => 'Neurgarria';

  @override
  String get measurableExample =>
      'Adib. Zenbat kilometro egin dituzu gaur? Zenbat orrialde irakurri dituzu?';

  @override
  String xTimesPerWeek(int p1) {
    return 'Astean $p1 aldiz';
  }

  @override
  String xTimesPerMonth(int p1) {
    return 'Hilean $p1 aldiz';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 aldiz $p2 egunetan';
  }

  @override
  String get yesOrNoShortExample => 'adib. Ariketa';

  @override
  String get color => 'Kolorea';

  @override
  String get exampleTarget => 'adib. 15';

  @override
  String get measurableShortExample => 'adib. Korrika egin';

  @override
  String get measurableQuestionExample =>
      'adib. Zenbat kilometro egin dituzu korrika gaur?';

  @override
  String get measurableUnitsExample => 'adib. Kilometroak';

  @override
  String get everyMonth => 'Hilabetero';

  @override
  String get validationCannotBeBlank => 'Ezin da hutsik egon';

  @override
  String get today => 'Gaur';

  @override
  String get enter => 'Sartu';

  @override
  String get noHabits => 'Ez da ohiturarik aurkitu';

  @override
  String get noNumericalHabits => 'Ez da aurkitu ohitura neurgarririk';

  @override
  String get noBooleanHabits => 'Ez da bai-ala-ez ohiturarik aurkitu';

  @override
  String get increment => 'Increment';

  @override
  String get decrement => 'Decrement';

  @override
  String get prefSkipTitle => 'Gaitu atseden egunak';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Sakatu bi aldiz kontrol-markaren ordez atseden bat gehitzeko. Atsedenek zure puntuazioa aldatu gabe mantentzen dute eta ez dute segida hausten.';

  @override
  String get prefUnknownTitle => 'Adierazi galdera ikurra falta diren datuetan';

  @override
  String get prefUnknownDescription =>
      'Bereizi daturik gabeko egunak benetako hutsegiteetatik. Hutsegite bat sartzeko, sakatu bi aldiz.';

  @override
  String get youAreNowADeveloper => 'Garatzailea zara!';

  @override
  String get activityNotFound =>
      'Ez da aurkitu akzio hau gauzatu dezakeen aplikaziorik';

  @override
  String get prefMidnightDelayTitle =>
      'Luzatu eguna gauerdia osteko ordu batzuetara';

  @override
  String get prefMidnightDelayDescription =>
      'Itxaron goizeko 3:00ak arte egun berri bat erakusteko. Erabilgarria normalean gauerdia pasata lotara joaten bazara. Aplikazioa berrabiarazi behar da.';

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
      other: 'Ohiturak aldatu dira',
      one: 'Ohitura aldatu da',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohiturak ezabatu dira',
      one: 'Ohitura ezabatu da',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohiturak artxibatu dira',
      one: 'Ohitura artxibatu da',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohiturak desartxibatu dira',
      one: 'Ohitura desartxibatu da',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohiturak ezabatu',
      one: 'Ohiturak ezabatu',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ohiturak betirako ezabatuko dira. Ekintza hau ezin da desegin.',
      one: 'Ohitura betirako ezabatuko da. Ekintza hau ezin da desegin.',
    );
    return '$_temp0';
  }
}
