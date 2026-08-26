// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Armenian (`hy`).
class L10nHy extends L10n {
  L10nHy([String locale = 'hy']) : super(locale);

  @override
  String get overview => 'Overview';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Սովորություններ';

  @override
  String get actionSettings => 'Կարգավորումներ';

  @override
  String get edit => 'Փոփոխել';

  @override
  String get delete => 'Ջնջել';

  @override
  String get archive => 'Արխիվ';

  @override
  String get unarchive => 'Անարխիվ';

  @override
  String get addHabit => 'Ավելացնել սովորություն';

  @override
  String get colorPickerDefaultTitle => 'Փոխել գույնը';

  @override
  String get toastHabitCreated => 'Սովորությունը ստեղծեց';

  @override
  String get habitStrength => 'Habit strength';

  @override
  String get history => 'Պատմություն';

  @override
  String get clear => 'Մաքրել';

  @override
  String get reminder => 'Հիշեցում';

  @override
  String get save => 'Պահել';

  @override
  String get streaks => 'Streaks';

  @override
  String get noHabitsFound => 'You have no active habits';

  @override
  String get noHabitsLeftToDo => 'You\'re all done for today!';

  @override
  String get longPressToToggle => 'Press-and-hold to check or uncheck';

  @override
  String get reminderOff => 'Անջ.';

  @override
  String get createHabit => 'Ստեղծել սովորությունը';

  @override
  String get editHabit => 'Փոփոխել սովորությունը';

  @override
  String get check => 'Check';

  @override
  String get snooze => 'Հետո';

  @override
  String get introTitle1 => 'Բարի գալուստ';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker helps you create and maintain good habits.';

  @override
  String get introTitle2 => 'Create some new habits';

  @override
  String get introDescription2 =>
      'Every day, after performing your habit, put a checkmark on the app.';

  @override
  String get introTitle4 => 'Track your progress';

  @override
  String get introDescription4 =>
      'Detailed graphs show you how your habits improved over time.';

  @override
  String get interval15Minutes => '15 րոպե';

  @override
  String get interval30Minutes => '30 րոպե';

  @override
  String get interval1Hour => '1 ժամ';

  @override
  String get interval2Hour => '2 ժամ';

  @override
  String get interval4Hour => '4 ժամ';

  @override
  String get interval8Hour => '8 ժամ';

  @override
  String get interval24Hour => '24 ժամ';

  @override
  String get intervalAlwaysAsk => 'Միշտ հարցնել';

  @override
  String get intervalCustom => 'Custom...';

  @override
  String get prefToggleTitle => 'Toggle with short press';

  @override
  String get prefToggleDescription2 =>
      'Put checkmarks with a single tap instead of press-and-hold.';

  @override
  String get prefRateThisApp => 'Rate this app on Google Play';

  @override
  String get prefSendFeedback => 'Send feedback to developer';

  @override
  String get prefViewSourceCode => 'View source code at GitHub';

  @override
  String get links => 'Հղումներ';

  @override
  String get name => 'Անուն';

  @override
  String get settings => 'Կարգավորումներ';

  @override
  String get selectSnoozeDelay => 'Select snooze delay';

  @override
  String get hintTitle => 'Գիտե՞ք';

  @override
  String get hintDrag =>
      'To rearrange the entries, press-and-hold on the name of the habit, then drag it to the correct place.';

  @override
  String get hintLandscape =>
      'You can see more days by putting your phone in landscape mode.';

  @override
  String get habitNotFound => 'Habit deleted / not found';

  @override
  String get weekends => 'Հանգստյան օրեր';

  @override
  String get anyWeekday => 'Monday to Friday';

  @override
  String get anyDay => 'Any day of the week';

  @override
  String get selectWeekdays => 'Նշել օրեր';

  @override
  String get exportToCsv => 'Export as CSV';

  @override
  String get doneLabel => 'Պատրաստ է';

  @override
  String get clearLabel => 'Մաքրել';

  @override
  String get selectHours => 'Select hours';

  @override
  String get selectMinutes => 'Select minutes';

  @override
  String get about => 'Մասին';

  @override
  String get translators => 'Թարգմանիչներ';

  @override
  String get developers => 'Developers';

  @override
  String versionN(String p1) {
    return 'Տարբերակ $p1';
  }

  @override
  String get frequency => 'Հաճախություն';

  @override
  String get checkmark => 'Checkmark';

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
  String get bestStreaks => 'Best streaks';

  @override
  String get everyDay => 'Ամեն օր';

  @override
  String get everyWeek => 'Ամեն շաբաթ';

  @override
  String get help => 'Help & FAQ';

  @override
  String get couldNotExport => 'Failed to export data.';

  @override
  String get couldNotImport => 'Failed to import data.';

  @override
  String get fileNotRecognized => 'File not recognized.';

  @override
  String get habitsImported => 'Habits imported successfully.';

  @override
  String get importData => 'Import data';

  @override
  String get exportFullBackup => 'Export full backup';

  @override
  String get importDataSummary =>
      'Supports full backups exported by this app, as well as files generated by Tickmate, HabitBull or Rewire. See FAQ for more information.';

  @override
  String get exportAsCsvSummary =>
      'Generates files that can be opened by spreadsheet software such as Microsoft Excel or OpenOffice Calc. This file cannot be imported back.';

  @override
  String get exportFullBackupSummary =>
      'Generates a file that contains all your data. This file can be imported back.';

  @override
  String get selectPublicBackupFolder =>
      'Ընտրեք հանրային պահուստային թղթապանակը';

  @override
  String get noPublicBackupFolderSelected => 'Թղթապանակ չի ընտրվել';

  @override
  String get bugReportFailed => 'Failed to generate bug report.';

  @override
  String get generateBugReport => 'Generate bug report';

  @override
  String get troubleshooting => 'Troubleshooting';

  @override
  String get helpTranslate => 'Help translate this app';

  @override
  String get nightMode => 'Մուգ տեսք';

  @override
  String get usePureBlack => 'Use pure black in dark theme';

  @override
  String get pureBlackDescription =>
      'Replaces gray backgrounds with pure black in dark theme. Reduces battery usage in phones with AMOLED display.';

  @override
  String get interfacePreferences => 'Interface';

  @override
  String get reverseDays => 'Reverse order of days';

  @override
  String get reverseDaysDescription =>
      'Show days in reverse order on the main screen.';

  @override
  String get day => 'Օր';

  @override
  String get week => 'Շաբաթ';

  @override
  String get month => 'Ամիս';

  @override
  String get quarter => 'Quarter';

  @override
  String get year => 'Տարի';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Այո կամ ոչ';

  @override
  String everyXDays(int p1) {
    return 'Ամեն $p1 օրը մեկ';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Ամեն $p1 շաբաթը մեկ';
  }

  @override
  String get score => 'Score';

  @override
  String get reminderSound => 'Reminder sound';

  @override
  String get none => 'None';

  @override
  String get filter => 'Զտել';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Hide completed';

  @override
  String get hideEntered => 'Hide entered';

  @override
  String get hideArchived => 'Hide archived';

  @override
  String get stickyNotifications => 'Make notifications sticky';

  @override
  String get stickyNotificationsDescription =>
      'Prevents notifications from being swiped away.';

  @override
  String get ledNotifications => 'Notification light';

  @override
  String get ledNotificationsDescription =>
      'Shows a blinking light for reminders. Only available in phones with LED notification lights.';

  @override
  String get repairDatabase => 'Repair database';

  @override
  String get databaseRepaired => 'Database repaired.';

  @override
  String get uncheck => 'Uncheck';

  @override
  String get toggle => 'Toggle';

  @override
  String get action => 'Action';

  @override
  String get habit => 'Սովորություն';

  @override
  String get sort => 'Sort';

  @override
  String get manually => 'Ձեռքով';

  @override
  String get byName => 'Անունով';

  @override
  String get byColor => 'Գույնով';

  @override
  String get byScore => 'By score';

  @override
  String get byStatus => 'By status';

  @override
  String get export => 'Export';

  @override
  String get longPressToEdit => 'Press-and-hold to change the value';

  @override
  String get value => 'Value';

  @override
  String get calendar => 'Օրացույց';

  @override
  String get unit => 'Միավոր';

  @override
  String get targetType => 'Target Type';

  @override
  String get targetTypeAtLeast => 'At least';

  @override
  String get targetTypeAtMost => 'At most';

  @override
  String get exampleQuestionBoolean => 'e.g. Did you exercise today?';

  @override
  String get question => 'Հարց';

  @override
  String get target => 'Target';

  @override
  String get yes => 'Այո';

  @override
  String get no => 'Ոչ';

  @override
  String get customizeNotificationSummary =>
      'Change sound, vibration, light and other notification settings';

  @override
  String get customizeNotification => 'Customize notifications';

  @override
  String get prefViewPrivacy => 'View privacy policy';

  @override
  String get viewAllContributors => 'View all contributors…';

  @override
  String get database => 'Database';

  @override
  String get widgetOpacityTitle => 'Widget opacity';

  @override
  String get widgetOpacityDescription =>
      'Makes widgets more transparent or more opaque in your home screen.';

  @override
  String get firstDayOfTheWeek => 'First day of the week';

  @override
  String get defaultReminderQuestion => 'Have you completed this habit today?';

  @override
  String get notes => 'Notes';

  @override
  String get exampleNotes => '(Optional)';

  @override
  String get yesOrNoExample =>
      'e.g. Did you wake up early today? Did you exercise? Did you play chess?';

  @override
  String get measurable => 'Չափելի';

  @override
  String get measurableExample =>
      'e.g. How many miles did you run today? How many pages did you read?';

  @override
  String xTimesPerWeek(int p1) {
    return 'Շաբաթական $p1 անգամ';
  }

  @override
  String xTimesPerMonth(int p1) {
    return 'Ամսական $p1 անգամ';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 times in $p2 days';
  }

  @override
  String get yesOrNoShortExample => 'e.g. Exercise';

  @override
  String get color => 'Գույն';

  @override
  String get exampleTarget => 'e.g. 15';

  @override
  String get measurableShortExample => 'e.g. Run';

  @override
  String get measurableQuestionExample =>
      'e.g. How many miles did you run today?';

  @override
  String get measurableUnitsExample => 'e.g. miles';

  @override
  String get everyMonth => 'Every month';

  @override
  String get validationCannotBeBlank => 'Cannot be blank';

  @override
  String get today => 'Այսօր';

  @override
  String get enter => 'Enter';

  @override
  String get noHabits => 'No habits found';

  @override
  String get noNumericalHabits => 'No measurable habits found';

  @override
  String get noBooleanHabits => 'No yes-or-no habits found';

  @override
  String get increment => 'Increment';

  @override
  String get decrement => 'Decrement';

  @override
  String get prefSkipTitle => 'Enable skip days';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Toggle twice to add a skip instead of a checkmark. Skips keep your score unchanged and don\'t break your streak.';

  @override
  String get prefUnknownTitle => 'Show question marks for missing data';

  @override
  String get prefUnknownDescription =>
      'Differentiate days without data from actual lapses. To enter a lapse, toggle twice.';

  @override
  String get youAreNowADeveloper => 'You are now a developer';

  @override
  String get activityNotFound => 'No app was found to support this action';

  @override
  String get prefMidnightDelayTitle => 'Extend day a few hours past midnight';

  @override
  String get prefMidnightDelayDescription =>
      'Wait until 3:00 AM to show a new day. Useful if you typically go to sleep after midnight. Requires app restart.';

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
      other: 'Habits changed',
      one: 'Habit changed',
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
      other: 'Habits unarchived',
      one: 'Habit unarchived',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete habits?',
      one: 'Delete habit?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The habits will be permanently deleted. This action cannot be undone.',
      one:
          'The habit will be permanently deleted. This action cannot be undone.',
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
