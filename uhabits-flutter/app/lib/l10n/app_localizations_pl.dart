// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class L10nPl extends L10n {
  L10nPl([String locale = 'pl']) : super(locale);

  @override
  String get overview => 'Przegląd';

  @override
  String get appName => 'Śledzenie Nawyków Loop';

  @override
  String get mainActivityTitle => 'Nawyki';

  @override
  String get actionSettings => 'Ustawienia';

  @override
  String get edit => 'Edytuj';

  @override
  String get delete => 'Usuń';

  @override
  String get archive => 'Archiwizuj';

  @override
  String get unarchive => 'Odarchiwizuj';

  @override
  String get addHabit => 'Dodaj nawyk';

  @override
  String get colorPickerDefaultTitle => 'Zmień kolor';

  @override
  String get toastHabitCreated => 'Utworzono nawyk';

  @override
  String get habitStrength => 'Siła nawyku';

  @override
  String get history => 'Historia';

  @override
  String get clear => 'Wyczyść';

  @override
  String get reminder => 'Przypomnienie';

  @override
  String get save => 'Zapisz';

  @override
  String get streaks => 'Serie';

  @override
  String get noHabitsFound => 'Nie masz aktywnych nawyków';

  @override
  String get noHabitsLeftToDo => 'Na dziś to wszystko!';

  @override
  String get longPressToToggle =>
      'Naciśnij i przytrzymaj aby zaznaczyć lub odznaczyć';

  @override
  String get reminderOff => 'Wyłączone';

  @override
  String get createHabit => 'Utwórz nawyk';

  @override
  String get editHabit => 'Edytuj nawyk';

  @override
  String get check => 'Zaznacz';

  @override
  String get snooze => 'Później';

  @override
  String get introTitle1 => 'Witaj';

  @override
  String get introDescription1 =>
      'Śledzenie nawyków Loop pozwala Ci na utworzenie i prowadzenie dobrych nawyków.';

  @override
  String get introTitle2 => 'Utwórz nowe nawyki';

  @override
  String get introDescription2 =>
      'Codziennie, po wykonaniu swojego nawyku, postaw znaczek w aplikacji.';

  @override
  String get introTitle4 => 'Śledź swój postęp';

  @override
  String get introDescription4 =>
      'Szczegółowe grafiki pokazują jak Twoje nawyki polepszyły się z biegiem czasu.';

  @override
  String get interval15Minutes => '15 minut';

  @override
  String get interval30Minutes => '30 minut';

  @override
  String get interval1Hour => '1 godzina';

  @override
  String get interval2Hour => '2 godziny';

  @override
  String get interval4Hour => '4 godziny';

  @override
  String get interval8Hour => '8 godzin';

  @override
  String get interval24Hour => '24 godziny';

  @override
  String get intervalAlwaysAsk => 'Zawsze pytaj';

  @override
  String get intervalCustom => 'Własne ustawienia...';

  @override
  String get prefToggleTitle => 'Przełącz powtarzanie krótkim naciśnięciem';

  @override
  String get prefToggleDescription2 =>
      'Umieść znaczniki wyboru jednym dotknięciem zamiast naciśnięcia i przytrzymania.';

  @override
  String get prefRateThisApp => 'Oceń tę aplikację w Google Play';

  @override
  String get prefSendFeedback => 'Prześlij uwagi do programisty';

  @override
  String get prefViewSourceCode => 'Zobacz kod źródłowy na GitHub\'ie';

  @override
  String get links => 'Linki';

  @override
  String get name => 'Nazwa';

  @override
  String get settings => 'Ustawienia';

  @override
  String get selectSnoozeDelay => 'Wybierz długość drzemki';

  @override
  String get hintTitle => 'Czy wiesz że?';

  @override
  String get hintDrag =>
      'Aby zmienić kolejność naciśnij i przytrzymaj na nazwie nawyku i przesuń go na odpowiednie miejsce.';

  @override
  String get hintLandscape =>
      'Możesz zobaczyć więcej dni trzymając telefon poziomo.';

  @override
  String get habitNotFound => 'Nawyk usunięty/nie znaleziony';

  @override
  String get weekends => 'Weekendy';

  @override
  String get anyWeekday => 'Dni robocze';

  @override
  String get anyDay => 'Każdy dzień';

  @override
  String get selectWeekdays => 'Wybierz dni';

  @override
  String get exportToCsv => 'Eksportuj dane (CSV)';

  @override
  String get doneLabel => 'Gotowe';

  @override
  String get clearLabel => 'Wyczyść';

  @override
  String get selectHours => 'Wybierz godziny';

  @override
  String get selectMinutes => 'Wybierz minuty';

  @override
  String get about => 'O aplikacji';

  @override
  String get translators => 'Tłumacze';

  @override
  String get developers => 'Programiści';

  @override
  String versionN(String p1) {
    return 'Wersja $p1';
  }

  @override
  String get frequency => 'Częstotliwość';

  @override
  String get checkmark => 'Znacznik';

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
  String get bestStreaks => 'Najlepsze serie';

  @override
  String get everyDay => 'Codziennie';

  @override
  String get everyWeek => 'Co tydzień';

  @override
  String get help => 'Pomoc & FAQ';

  @override
  String get couldNotExport => 'Eksportowanie danych nie powiodło się.';

  @override
  String get couldNotImport => 'Importowanie danych nie powiodło się.';

  @override
  String get fileNotRecognized => 'Plik nierozpoznany.';

  @override
  String get habitsImported => 'Nawyki zaimportowane pomyślnie.';

  @override
  String get importData => 'Importuj dane';

  @override
  String get exportFullBackup => 'Eksportuj pełną kopię zapasową';

  @override
  String get importDataSummary =>
      'Wspiera pełne kopie zapasowe wyeksportowane przez tą aplikację zarówno jak i pliki wygenerowane przez Tickmate, Habitbull oraz Rewire. Zobacz FAQ po więcej informacji.';

  @override
  String get exportAsCsvSummary =>
      'Generuje pliki, które mogą być otwierane przez arkusze kalkulacyjne takie jak Microsoft Excel czy OpenOffice Calc. Taki plik nie może być importowany.';

  @override
  String get exportFullBackupSummary =>
      'Generuje plik, który zawiera wszystkie Twoje dane. Taki plik może być importowany.';

  @override
  String get selectPublicBackupFolder =>
      'Wybierz publiczny folder kopii zapasowych';

  @override
  String get noPublicBackupFolderSelected => 'Nie wybrano folderu';

  @override
  String get bugReportFailed => 'Nie udało się wygenerować raportu o błędach.';

  @override
  String get generateBugReport => 'Wygeneruj raport o błędach';

  @override
  String get troubleshooting => 'Rozwiązywanie problemów';

  @override
  String get helpTranslate => 'Pomóż w tłumaczeniu tej aplikacji';

  @override
  String get nightMode => 'Tryb nocny';

  @override
  String get usePureBlack => 'Używaj pełnej czerni w trybie nocnym';

  @override
  String get pureBlackDescription =>
      'Zamienia szare tła na pełną czerń w trybie nocnym. Zmniejsza zużycie baterii w telefonach z ekranem AMOLED.';

  @override
  String get interfacePreferences => 'Interfejs';

  @override
  String get reverseDays => 'Odwróć kolejność dni';

  @override
  String get reverseDaysDescription =>
      'Pokaż dni w odwrotnej kolejności na głównym ekranie';

  @override
  String get day => 'Dzień';

  @override
  String get week => 'Tydzień';

  @override
  String get month => 'Miesiąc';

  @override
  String get quarter => 'Kwartał';

  @override
  String get year => 'Rok';

  @override
  String get total => 'Łącznie';

  @override
  String get yesOrNo => 'Tak lub Nie';

  @override
  String everyXDays(int p1) {
    return 'Co $p1 dni';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Co $p1 tygodni';
  }

  @override
  String get score => 'Wynik';

  @override
  String get reminderSound => 'Dźwięk przypomnienia';

  @override
  String get none => 'Brak';

  @override
  String get filter => 'Filtruj';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Ukryj zakończone';

  @override
  String get hideEntered => 'Ukryj wprowadzone';

  @override
  String get hideArchived => 'Ukryj archiwizowane';

  @override
  String get stickyNotifications => 'Przypinaj powiadomienia';

  @override
  String get stickyNotificationsDescription =>
      'Zapobiega usunięciu powiadomień.';

  @override
  String get ledNotifications => 'Dioda powiadomień';

  @override
  String get ledNotificationsDescription =>
      'Wyświetla migające światło dla przypomnień. Dostępne jedynie w telefonach z diodą LED.';

  @override
  String get repairDatabase => 'Napraw bazę danych';

  @override
  String get databaseRepaired => 'Baza danych została naprawiona.';

  @override
  String get uncheck => 'Odznacz';

  @override
  String get toggle => 'Przełącz';

  @override
  String get action => 'Akcja';

  @override
  String get habit => 'Nawyk';

  @override
  String get sort => 'Sortuj';

  @override
  String get manually => 'Ręcznie';

  @override
  String get byName => 'Według nazwy';

  @override
  String get byColor => 'Według koloru';

  @override
  String get byScore => 'Według wyniku';

  @override
  String get byStatus => 'Według statusu';

  @override
  String get export => 'Eksportuj';

  @override
  String get longPressToEdit => 'Naciśnij i przytrzymaj, aby zmienić wartość';

  @override
  String get value => 'Wartość';

  @override
  String get calendar => 'Kalendarz';

  @override
  String get unit => 'Jednostka';

  @override
  String get targetType => 'Rodzaj celu:';

  @override
  String get targetTypeAtLeast => 'Co najmniej';

  @override
  String get targetTypeAtMost => 'Maksymalnie';

  @override
  String get exampleQuestionBoolean => 'np. Czy ćwiczyłeś dzisiaj?';

  @override
  String get question => 'Pytanie';

  @override
  String get target => 'Cel';

  @override
  String get yes => 'Tak';

  @override
  String get no => 'Nie';

  @override
  String get customizeNotificationSummary =>
      'Zmień dźwięk, wibrację, światło i inne ustawienia powiadomień';

  @override
  String get customizeNotification => 'Dostosuj powiadomienia';

  @override
  String get prefViewPrivacy => 'Zobacz politykę prywatności';

  @override
  String get viewAllContributors => 'Zobacz wszystkich współtwórców';

  @override
  String get database => 'Baza danych';

  @override
  String get widgetOpacityTitle => 'Przezroczystość widżetu';

  @override
  String get widgetOpacityDescription =>
      'Sprawia, że widżety są bardziej lub mniej przezroczyste na ekranie głównym.';

  @override
  String get firstDayOfTheWeek => 'Pierwszy dzień tygodnia';

  @override
  String get defaultReminderQuestion => 'Czy wytrwałeś dziś w nawyku?';

  @override
  String get notes => 'Notatki';

  @override
  String get exampleNotes => '(opcjonalne)';

  @override
  String get yesOrNoExample =>
      'np. Czy obudziłeś się dzisiaj wcześnie? Czy ćwiczyłeś? Czy grałeś w szachy?';

  @override
  String get measurable => 'Mierzalne';

  @override
  String get measurableExample =>
      'np. Ile mil przejechałeś dzisiaj? Ile stron przeczytałeś?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 razy w tygodniu';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 razy w miesiącu';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 razy w ciągu $p2 dni';
  }

  @override
  String get yesOrNoShortExample => 'np. ćwiczenia';

  @override
  String get color => 'Kolor';

  @override
  String get exampleTarget => 'np. 15';

  @override
  String get measurableShortExample => 'np. Bieg';

  @override
  String get measurableQuestionExample =>
      'np. Ile kilometrów dzisiaj przebiegłeś?';

  @override
  String get measurableUnitsExample => 'np. kilometry';

  @override
  String get everyMonth => 'Każdego miesiąca';

  @override
  String get validationCannotBeBlank => 'Pole nie może być puste';

  @override
  String get today => 'Dzisiaj';

  @override
  String get enter => 'Wprowadź';

  @override
  String get noHabits => 'Nie znaleziono nawyków';

  @override
  String get noNumericalHabits => 'Nie znaleziono mierzalnych nawyków';

  @override
  String get noBooleanHabits => 'Nie znaleziono nawyków typu tak/nie';

  @override
  String get increment => 'Zwiększ';

  @override
  String get decrement => 'Zmniejsz';

  @override
  String get prefSkipTitle => 'Włącz pomijanie dni';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Przełącz dwukrotnie, aby dodać pominięcie zamiast znacznika wyboru. Pomijanie utrzymuje niezmieniony wynik i nie przerywa passy.';

  @override
  String get prefUnknownTitle => 'Pokaż znaki zapytania dla brakujących danych';

  @override
  String get prefUnknownDescription =>
      'Odróżnij dni bez danych od faktycznych przerw. Aby wprowadzić przerwę, przełącz dwukrotnie.';

  @override
  String get youAreNowADeveloper => 'Jesteś teraz programistą';

  @override
  String get activityNotFound =>
      'Nie znaleziono aplikacji obsługującej to działanie';

  @override
  String get prefMidnightDelayTitle =>
      'Przedłuż dzień o kilka godzin po północy';

  @override
  String get prefMidnightDelayDescription =>
      'Poczekaj do 3:00, aby pokazać nowy dzień. Przydatne, jeśli zwykle kładziesz się spać po północy. Wymaga ponownego uruchomienia aplikacji.';

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
      other: 'Zmieniono nawyki',
      many: 'Zmieniono nawyki',
      few: 'Zmieniono nawyki',
      one: 'Zmieniono nawyk',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto nawyki',
      many: 'Nawyki usunięte',
      few: 'Nawyki usunięte',
      one: 'Nawyk usunięty',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zarchiwizowano nawyki',
      many: 'Zarchiwizowano nawyki',
      few: 'Zarchiwizowano nawyki',
      one: 'Zarchiwizowano nawyk',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nawyki zostały przywrócone z archiwum',
      many: 'Nawyki zostały przywrócone z archiwum',
      few: 'Nawyki zostały przywrócone z archiwum',
      one: 'Nawyk przywrócony z archiwum',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunąć nawyki?',
      many: 'Usunąć nawyki?',
      few: 'Usunąć nawyki?',
      one: 'Usunąć nawyk?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nawyki zostaną trwale usunięte. Tej czynności nie można cofnąć.',
      many: 'Nawyki zostaną trwale usunięte. Tej czynności nie można cofnąć.',
      few: 'Nawyki zostaną trwale usunięte. Tej czynności nie można cofnąć.',
      one: 'Nawyk zostanie trwale usunięty. Tej czynności nie można cofnąć.',
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
}
