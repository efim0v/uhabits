// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class L10nHu extends L10n {
  L10nHu([String locale = 'hu']) : super(locale);

  @override
  String get overview => 'Áttekintés';

  @override
  String get appName => 'Loop Szokásrögzítő';

  @override
  String get mainActivityTitle => 'Szokások';

  @override
  String get actionSettings => 'Beállítások';

  @override
  String get edit => 'Szerkesztés';

  @override
  String get delete => 'Törlés';

  @override
  String get archive => 'Archiválás';

  @override
  String get unarchive => 'Újraaktiválás';

  @override
  String get addHabit => 'Új szokás';

  @override
  String get colorPickerDefaultTitle => 'Szín módosítása';

  @override
  String get toastHabitCreated => 'Szokás létrehozva';

  @override
  String get habitStrength => 'Szokás erőssége';

  @override
  String get history => 'Napló';

  @override
  String get clear => 'Törlés';

  @override
  String get reminder => 'Emlékeztető';

  @override
  String get save => 'Mentés';

  @override
  String get streaks => 'Szériák';

  @override
  String get noHabitsFound => 'Nincs aktív szokásod';

  @override
  String get noHabitsLeftToDo => 'Mára minden kész!';

  @override
  String get longPressToToggle =>
      'Tartsd lenyomva a bejelöléshez, vagy a jelölés törléséhez';

  @override
  String get reminderOff => 'Kikapcsolva';

  @override
  String get createHabit => 'Szokás rögzítése';

  @override
  String get editHabit => 'Szokás szerkesztése';

  @override
  String get check => 'Kipipálva';

  @override
  String get snooze => 'Később';

  @override
  String get introTitle1 => 'Üdv!';

  @override
  String get introDescription1 =>
      'A Loop Habit Tracker segít a jó szokások kialakításában és azok fenntartásában';

  @override
  String get introTitle2 => 'Hozz létre néhány új szokást';

  @override
  String get introDescription2 =>
      'Minden nap jelöld pipával az alkalmazásban, ahogy elvégeztél egy jó szokást.';

  @override
  String get introTitle4 => 'Kövesd a fejlődésed';

  @override
  String get introDescription4 =>
      'A szokások fejlődésének időbeni alakulását részletes grafikonok mutatják.';

  @override
  String get interval15Minutes => '15 perc';

  @override
  String get interval30Minutes => '30 perc';

  @override
  String get interval1Hour => '1 óra';

  @override
  String get interval2Hour => '2 óra';

  @override
  String get interval4Hour => '4 óra';

  @override
  String get interval8Hour => '8 óra';

  @override
  String get interval24Hour => '24 óra';

  @override
  String get intervalAlwaysAsk => 'Mindig rákérdez';

  @override
  String get intervalCustom => 'Egyedi...';

  @override
  String get prefToggleTitle => 'Bejelölés rövid koppintással';

  @override
  String get prefToggleDescription2 =>
      'Nyomva tartás helyett koppintással tudja a napokat kipipálni.';

  @override
  String get prefRateThisApp => 'Értékeld az alkalmazást a Google Play-en';

  @override
  String get prefSendFeedback => 'Visszajelzés küldése a fejlesztőnek';

  @override
  String get prefViewSourceCode => 'Forráskód megtekintése a GitHub-on';

  @override
  String get links => 'Linkek';

  @override
  String get name => 'Megnevezés';

  @override
  String get settings => 'Beállítások';

  @override
  String get selectSnoozeDelay => 'Szundi beállítása';

  @override
  String get hintTitle => 'Tudtad?';

  @override
  String get hintDrag =>
      'Az elemek újrarendezéséhez a koppints a szokás nevére, majd húzd a megfelelő helyre.';

  @override
  String get hintLandscape =>
      'Több nap válik láthatóvá, ha fekvő módba állítod a telefonod kijelzőjét.';

  @override
  String get habitNotFound => 'Szokás törölve / nem található';

  @override
  String get weekends => 'Hétvégente';

  @override
  String get anyWeekday => 'Hétfőtől péntekig';

  @override
  String get anyDay => 'A hét bármely napján';

  @override
  String get selectWeekdays => 'Napok kiválasztása';

  @override
  String get exportToCsv => 'Exportálás CSV-ként';

  @override
  String get doneLabel => 'Kész';

  @override
  String get clearLabel => 'Törlés';

  @override
  String get selectHours => 'Óra kiválasztása';

  @override
  String get selectMinutes => 'Perc kiválasztása';

  @override
  String get about => 'Névjegy';

  @override
  String get translators => 'Fordítók';

  @override
  String get developers => 'Fejlesztők';

  @override
  String versionN(String p1) {
    return 'Verzió $p1';
  }

  @override
  String get frequency => 'Gyakoriság';

  @override
  String get checkmark => 'Pipa';

  @override
  String get checkmarkStackWidget => 'Pipa Stack Widget';

  @override
  String get frequencyStackWidget => 'Gyakoriság Stack-widget';

  @override
  String get scoreStackWidget => 'Pontszám stack-widget';

  @override
  String get historyStackWidget => 'Előzmények stack-widget';

  @override
  String get streaksStackWidget => 'Sorozat Stack Widget';

  @override
  String get bestStreaks => 'Legjobb széria';

  @override
  String get everyDay => 'Minden nap';

  @override
  String get everyWeek => 'Minden héten';

  @override
  String get help => 'Súgó és GYIK';

  @override
  String get couldNotExport => 'Nem sikerült az adatok exportálása.';

  @override
  String get couldNotImport => 'Nem sikerült az adatok importálása';

  @override
  String get fileNotRecognized => 'A fájlt nem sikerült felismerni.';

  @override
  String get habitsImported => 'A szokások importálása sikerült.';

  @override
  String get importData => 'Adat importálása';

  @override
  String get exportFullBackup => 'Teljes mentés exportálása';

  @override
  String get importDataSummary =>
      'Támogatja a Loop Habit Tracker alkalmazás teljes mentéseit, illetve a Tickmate, HabitBull és Rewire alkalmazások formátumait is. További információt a GYIK-ben találsz.';

  @override
  String get exportAsCsvSummary =>
      'Olyan fájlokat generál, amit táblázatkezelőkkel lehet megnyitni (pl. Microsoft Excel-lel vagy OpenOffice Calc-kal). Ezt a fájlt nem lehet visszaimportálni.';

  @override
  String get exportFullBackupSummary =>
      'Olyan fájlt generál, amely tartalmazza minden adatodat. Ezt a fájlt vissza lehet importálni.';

  @override
  String get selectPublicBackupFolder =>
      'Nyilvános biztonsági mentési mappa kiválasztása';

  @override
  String get noPublicBackupFolderSelected => 'Nincs mappa kiválasztva';

  @override
  String get bugReportFailed => 'Nem sikerült a hibajelentés generálása';

  @override
  String get generateBugReport => 'Hibabejelentés generálása';

  @override
  String get troubleshooting => 'Hibaelhárítás';

  @override
  String get helpTranslate => 'Segíts lefordítani ezt az alkalmazást';

  @override
  String get nightMode => 'Éjszakai mód';

  @override
  String get usePureBlack => 'Fekete használata éjszakai módban';

  @override
  String get pureBlackDescription =>
      'A szürke hátteret tiszta feketére cseréli éjszakai módban. Csökkenti az energiafelhasználást AMOLED kijelzős telefonokon.';

  @override
  String get interfacePreferences => 'Kezelőfelület';

  @override
  String get reverseDays => 'Napok sorrendjének megfordítása';

  @override
  String get reverseDaysDescription =>
      'A főképernyőn fordított sorrendben mutatja a napokat';

  @override
  String get day => 'Nap';

  @override
  String get week => 'Hét';

  @override
  String get month => 'Hónap';

  @override
  String get quarter => 'Negyedév';

  @override
  String get year => 'Év';

  @override
  String get total => 'Összesen';

  @override
  String get yesOrNo => 'Igen vagy Nem';

  @override
  String everyXDays(int p1) {
    return '$p1 naponta';
  }

  @override
  String everyXWeeks(int p1) {
    return '$p1 hetente';
  }

  @override
  String get score => 'Pont';

  @override
  String get reminderSound => 'Emlékeztető dallama';

  @override
  String get none => 'Nem ismétlődik';

  @override
  String get filter => 'Szűrő';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Elvégzettek elrejtése';

  @override
  String get hideEntered =>
      'Ha bekapcsolta a kérdőjelek megjelenítését, akkor az \"Elvégzettek elrejtése\" helyett a \"Beírtak elrejtése\" fog megjelenni. Ez a beállítás elrejti az összes olyan szokást, amelyhez adat lett megadva, nem csak az elvégzetteket. Így el tudja rejteni azokat a szokásokat is, amelyekkel a nap elején kudarcot vallott.';

  @override
  String get hideArchived => 'Archiváltak elrejtése';

  @override
  String get stickyNotifications => 'Az értesítések legyenek ragadósak';

  @override
  String get stickyNotificationsDescription =>
      'Megakadályozza az értesítések eltávolítását';

  @override
  String get ledNotifications => 'Értesítési fény';

  @override
  String get ledNotificationsDescription =>
      'Emlékeztetés villogó fénnyel. Csak olyan telefonon működik amelyen van értesítési LED.';

  @override
  String get repairDatabase => 'Adatbázis javítása';

  @override
  String get databaseRepaired => 'Adatbázis javítása kész.';

  @override
  String get uncheck => 'Pipa kivétele';

  @override
  String get toggle => 'Ki/bekapcsolás';

  @override
  String get action => 'Művelet';

  @override
  String get habit => 'Szokás';

  @override
  String get sort => 'Rendezés';

  @override
  String get manually => 'Manuálisan';

  @override
  String get byName => 'Megnevezés szerint';

  @override
  String get byColor => 'Színek szerint';

  @override
  String get byScore => 'Pont szerint';

  @override
  String get byStatus => 'Állapot szerint';

  @override
  String get export => 'Exportálás';

  @override
  String get longPressToEdit => 'Az érték módosításához tartsd lenyomva';

  @override
  String get value => 'Érték';

  @override
  String get calendar => 'Naptár';

  @override
  String get unit => 'Egység';

  @override
  String get targetType => 'Célkitűzés típusa';

  @override
  String get targetTypeAtLeast => 'Legalább';

  @override
  String get targetTypeAtMost => 'Legfeljebb';

  @override
  String get exampleQuestionBoolean => 'pl. Edzettél ma?';

  @override
  String get question => 'Kérdés';

  @override
  String get target => 'Cél';

  @override
  String get yes => 'Igen';

  @override
  String get no => 'Nem';

  @override
  String get customizeNotificationSummary =>
      'Hang, rezgés, fény és egyéb értesítések beállítása';

  @override
  String get customizeNotification => 'Értesítések beállítása';

  @override
  String get prefViewPrivacy => 'Adatvédelmi nyilatkozat';

  @override
  String get viewAllContributors => 'Az összes közreműködő megtekintése…';

  @override
  String get database => 'Adatbázis';

  @override
  String get widgetOpacityTitle => 'A widget áttetszősége';

  @override
  String get widgetOpacityDescription =>
      'A widgetet átlátszóbbá vagy takaróbbá teszi az induló képernyőn.';

  @override
  String get firstDayOfTheWeek => 'A hét első napja';

  @override
  String get defaultReminderQuestion => 'Teljesítetted ma ezt a szokást?';

  @override
  String get notes => 'Jegyzetek';

  @override
  String get exampleNotes => '(opcionális)';

  @override
  String get yesOrNoExample => 'pl. Korán keltél ma fel? Edzettél? Sakkoztál?';

  @override
  String get measurable => 'Mérhető';

  @override
  String get measurableExample =>
      'pl. Hány kilométert futottál ma? Hány oldalt olvastál el?';

  @override
  String xTimesPerWeek(int p1) {
    return 'Heti $p1 alkalommal';
  }

  @override
  String xTimesPerMonth(int p1) {
    return 'Havi $p1 alkalommal';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 alk. / $p2 nap';
  }

  @override
  String get yesOrNoShortExample => 'pl. Edzés';

  @override
  String get color => 'Szín';

  @override
  String get exampleTarget => 'pl. 15';

  @override
  String get measurableShortExample => 'pl. Futás';

  @override
  String get measurableQuestionExample => 'pl. Hány kilométert futottál ma?';

  @override
  String get measurableUnitsExample => 'pl. kilométer';

  @override
  String get everyMonth => 'Minden hónapban';

  @override
  String get validationCannotBeBlank => 'Nem lehet üres';

  @override
  String get today => 'Ma';

  @override
  String get enter => 'Bevitel';

  @override
  String get noHabits => 'Nem találhatók szokások';

  @override
  String get noNumericalHabits => 'Nem található mérhető szokás';

  @override
  String get noBooleanHabits => 'Nem található igen-vagy-nem szokás';

  @override
  String get increment => 'Növelés';

  @override
  String get decrement => 'Csökkentés';

  @override
  String get prefSkipTitle => 'Napok kihagyásának engedélyezése';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Váltás kétszer, ha kihagyást szeretne hozzáadni a pipa helyett. A kihagyások változatlanul tartják a pontszámot, és nem szakítják meg a sorozatot.';

  @override
  String get prefUnknownTitle => 'Kérdőjelek megjelenítése a hiányzó adatoknál';

  @override
  String get prefUnknownDescription =>
      'Az adatok nélküli napok megkülönböztetése a tényleges kihagyásoktól. Kihagyás megadásához váltson kétszer.';

  @override
  String get youAreNowADeveloper => 'Ön mostantól már fejlesztő!';

  @override
  String get activityNotFound =>
      'Ezen művelet elvégzéséhez nem található alkalmazás.';

  @override
  String get prefMidnightDelayTitle =>
      'A nap meghosszabbítása éjfél után néhány órával';

  @override
  String get prefMidnightDelayDescription =>
      'Várjon hajnali 3 -ig, hogy új napot mutasson. Hasznos, ha általában éjfél után fekszik le. Az alkalmazás újraindítását igényli.';

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
      other: 'Szokások módosítva',
      one: 'Szokás módosítva',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Szokások törölve',
      one: 'Szokás törölve',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Szokások archiválva',
      one: 'Szokás archiválva',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Szokások újraaktiválva',
      one: 'Szokás újraaktiválva',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Törli a szokásokat?',
      one: 'Törli a szokást?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'A szokások véglegesen törölve lesznek. A műveletet nem lehet visszavonni.',
      one:
          'A szokás véglegesen törölve lesz. A műveletet nem lehet visszavonni.',
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
}
