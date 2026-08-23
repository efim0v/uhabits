import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_ca.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_eo.dart';
import 'app_localizations_es.dart';
import 'app_localizations_eu.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_he.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_hu.dart';
import 'app_localizations_hy.dart';
import 'app_localizations_id.dart';
import 'app_localizations_is.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ka.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_no.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sk.dart';
import 'app_localizations_sl.dart';
import 'app_localizations_sr.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ug.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('ar'),
    Locale('bg'),
    Locale('ca'),
    Locale('cs'),
    Locale('da'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('eo'),
    Locale('es'),
    Locale('eu'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('gu'),
    Locale('he'),
    Locale('hi'),
    Locale('hr'),
    Locale('hu'),
    Locale('hy'),
    Locale('id'),
    Locale('is'),
    Locale('it'),
    Locale('ja'),
    Locale('ka'),
    Locale('ko'),
    Locale('ml'),
    Locale('nl'),
    Locale('no'),
    Locale('pl'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('pt', 'PT'),
    Locale('ro'),
    Locale('ru'),
    Locale('sk'),
    Locale('sl'),
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
    Locale('sv'),
    Locale('ta'),
    Locale('te'),
    Locale('tr'),
    Locale('ug'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Loop Habit Tracker'**
  String get appName;

  /// No description provided for @mainActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get mainActivityTitle;

  /// No description provided for @actionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @addHabit.
  ///
  /// In en, this message translates to:
  /// **'Add habit'**
  String get addHabit;

  /// No description provided for @colorPickerDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get colorPickerDefaultTitle;

  /// No description provided for @toastHabitCreated.
  ///
  /// In en, this message translates to:
  /// **'Habit created'**
  String get toastHabitCreated;

  /// No description provided for @habitStrength.
  ///
  /// In en, this message translates to:
  /// **'Habit strength'**
  String get habitStrength;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @streaks.
  ///
  /// In en, this message translates to:
  /// **'Streaks'**
  String get streaks;

  /// No description provided for @noHabitsFound.
  ///
  /// In en, this message translates to:
  /// **'You have no active habits'**
  String get noHabitsFound;

  /// No description provided for @noHabitsLeftToDo.
  ///
  /// In en, this message translates to:
  /// **'You\'re all done for today!'**
  String get noHabitsLeftToDo;

  /// No description provided for @longPressToToggle.
  ///
  /// In en, this message translates to:
  /// **'Press-and-hold to check or uncheck'**
  String get longPressToToggle;

  /// No description provided for @reminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reminderOff;

  /// No description provided for @createHabit.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get createHabit;

  /// No description provided for @editHabit.
  ///
  /// In en, this message translates to:
  /// **'Edit habit'**
  String get editHabit;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get snooze;

  /// No description provided for @introTitle1.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get introTitle1;

  /// No description provided for @introDescription1.
  ///
  /// In en, this message translates to:
  /// **'Loop Habit Tracker helps you create and maintain good habits.'**
  String get introDescription1;

  /// No description provided for @introTitle2.
  ///
  /// In en, this message translates to:
  /// **'Create some new habits'**
  String get introTitle2;

  /// No description provided for @introDescription2.
  ///
  /// In en, this message translates to:
  /// **'Every day, after performing your habit, put a checkmark on the app.'**
  String get introDescription2;

  /// No description provided for @introTitle4.
  ///
  /// In en, this message translates to:
  /// **'Track your progress'**
  String get introTitle4;

  /// No description provided for @introDescription4.
  ///
  /// In en, this message translates to:
  /// **'Detailed graphs show you how your habits improved over time.'**
  String get introDescription4;

  /// No description provided for @interval15Minutes.
  ///
  /// In en, this message translates to:
  /// **'15 minutes'**
  String get interval15Minutes;

  /// No description provided for @interval30Minutes.
  ///
  /// In en, this message translates to:
  /// **'30 minutes'**
  String get interval30Minutes;

  /// No description provided for @interval1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get interval1Hour;

  /// No description provided for @interval2Hour.
  ///
  /// In en, this message translates to:
  /// **'2 hours'**
  String get interval2Hour;

  /// No description provided for @interval4Hour.
  ///
  /// In en, this message translates to:
  /// **'4 hours'**
  String get interval4Hour;

  /// No description provided for @interval8Hour.
  ///
  /// In en, this message translates to:
  /// **'8 hours'**
  String get interval8Hour;

  /// No description provided for @interval24Hour.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get interval24Hour;

  /// No description provided for @intervalAlwaysAsk.
  ///
  /// In en, this message translates to:
  /// **'Always ask'**
  String get intervalAlwaysAsk;

  /// No description provided for @intervalCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom...'**
  String get intervalCustom;

  /// No description provided for @prefToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Toggle with short press'**
  String get prefToggleTitle;

  /// No description provided for @prefToggleDescription2.
  ///
  /// In en, this message translates to:
  /// **'Put checkmarks with a single tap instead of press-and-hold.'**
  String get prefToggleDescription2;

  /// No description provided for @prefRateThisApp.
  ///
  /// In en, this message translates to:
  /// **'Rate this app on Google Play'**
  String get prefRateThisApp;

  /// No description provided for @prefSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback to developer'**
  String get prefSendFeedback;

  /// No description provided for @prefViewSourceCode.
  ///
  /// In en, this message translates to:
  /// **'View source code at GitHub'**
  String get prefViewSourceCode;

  /// No description provided for @links.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get links;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @selectSnoozeDelay.
  ///
  /// In en, this message translates to:
  /// **'Select snooze delay'**
  String get selectSnoozeDelay;

  /// No description provided for @hintTitle.
  ///
  /// In en, this message translates to:
  /// **'Did you know?'**
  String get hintTitle;

  /// No description provided for @hintDrag.
  ///
  /// In en, this message translates to:
  /// **'To rearrange the entries, press-and-hold on the name of the habit, then drag it to the correct place.'**
  String get hintDrag;

  /// No description provided for @hintLandscape.
  ///
  /// In en, this message translates to:
  /// **'You can see more days by putting your phone in landscape mode.'**
  String get hintLandscape;

  /// No description provided for @habitNotFound.
  ///
  /// In en, this message translates to:
  /// **'Habit deleted / not found'**
  String get habitNotFound;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @anyWeekday.
  ///
  /// In en, this message translates to:
  /// **'Monday to Friday'**
  String get anyWeekday;

  /// No description provided for @anyDay.
  ///
  /// In en, this message translates to:
  /// **'Any day of the week'**
  String get anyDay;

  /// No description provided for @selectWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Select days'**
  String get selectWeekdays;

  /// No description provided for @exportToCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportToCsv;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneLabel;

  /// No description provided for @clearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearLabel;

  /// No description provided for @selectHours.
  ///
  /// In en, this message translates to:
  /// **'Select hours'**
  String get selectHours;

  /// No description provided for @selectMinutes.
  ///
  /// In en, this message translates to:
  /// **'Select minutes'**
  String get selectMinutes;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @translators.
  ///
  /// In en, this message translates to:
  /// **'Translators'**
  String get translators;

  /// No description provided for @developers.
  ///
  /// In en, this message translates to:
  /// **'Developers'**
  String get developers;

  /// No description provided for @versionN.
  ///
  /// In en, this message translates to:
  /// **'Version {p1}'**
  String versionN(String p1);

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @checkmark.
  ///
  /// In en, this message translates to:
  /// **'Checkmark'**
  String get checkmark;

  /// No description provided for @checkmarkStackWidget.
  ///
  /// In en, this message translates to:
  /// **'Checkmark Stack Widget'**
  String get checkmarkStackWidget;

  /// No description provided for @frequencyStackWidget.
  ///
  /// In en, this message translates to:
  /// **'Frequency Stack Widget'**
  String get frequencyStackWidget;

  /// No description provided for @scoreStackWidget.
  ///
  /// In en, this message translates to:
  /// **'Score Stack Widget'**
  String get scoreStackWidget;

  /// No description provided for @historyStackWidget.
  ///
  /// In en, this message translates to:
  /// **'History Stack Widget'**
  String get historyStackWidget;

  /// No description provided for @streaksStackWidget.
  ///
  /// In en, this message translates to:
  /// **'Streaks Stack Widget'**
  String get streaksStackWidget;

  /// No description provided for @bestStreaks.
  ///
  /// In en, this message translates to:
  /// **'Best streaks'**
  String get bestStreaks;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get everyWeek;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get help;

  /// No description provided for @couldNotExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export data.'**
  String get couldNotExport;

  /// No description provided for @couldNotImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import data.'**
  String get couldNotImport;

  /// No description provided for @fileNotRecognized.
  ///
  /// In en, this message translates to:
  /// **'File not recognized.'**
  String get fileNotRecognized;

  /// No description provided for @habitsImported.
  ///
  /// In en, this message translates to:
  /// **'Habits imported successfully.'**
  String get habitsImported;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @exportFullBackup.
  ///
  /// In en, this message translates to:
  /// **'Export full backup'**
  String get exportFullBackup;

  /// No description provided for @importDataSummary.
  ///
  /// In en, this message translates to:
  /// **'Supports full backups exported by this app, as well as files generated by Tickmate, HabitBull or Rewire. See FAQ for more information.'**
  String get importDataSummary;

  /// No description provided for @exportAsCsvSummary.
  ///
  /// In en, this message translates to:
  /// **'Generates files that can be opened by spreadsheet software such as Microsoft Excel or OpenOffice Calc. This file cannot be imported back.'**
  String get exportAsCsvSummary;

  /// No description provided for @exportFullBackupSummary.
  ///
  /// In en, this message translates to:
  /// **'Generates a file that contains all your data. This file can be imported back.'**
  String get exportFullBackupSummary;

  /// No description provided for @selectPublicBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Select public backup folder'**
  String get selectPublicBackupFolder;

  /// No description provided for @noPublicBackupFolderSelected.
  ///
  /// In en, this message translates to:
  /// **'No folder selected'**
  String get noPublicBackupFolderSelected;

  /// No description provided for @bugReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate bug report.'**
  String get bugReportFailed;

  /// No description provided for @generateBugReport.
  ///
  /// In en, this message translates to:
  /// **'Generate bug report'**
  String get generateBugReport;

  /// No description provided for @troubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get troubleshooting;

  /// No description provided for @helpTranslate.
  ///
  /// In en, this message translates to:
  /// **'Help translate this app'**
  String get helpTranslate;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get nightMode;

  /// No description provided for @usePureBlack.
  ///
  /// In en, this message translates to:
  /// **'Use pure black in dark theme'**
  String get usePureBlack;

  /// No description provided for @pureBlackDescription.
  ///
  /// In en, this message translates to:
  /// **'Replaces gray backgrounds with pure black in dark theme. Reduces battery usage in phones with AMOLED display.'**
  String get pureBlackDescription;

  /// No description provided for @interfacePreferences.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get interfacePreferences;

  /// No description provided for @reverseDays.
  ///
  /// In en, this message translates to:
  /// **'Reverse order of days'**
  String get reverseDays;

  /// No description provided for @reverseDaysDescription.
  ///
  /// In en, this message translates to:
  /// **'Show days in reverse order on the main screen.'**
  String get reverseDaysDescription;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @quarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get quarter;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @yesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Yes or No'**
  String get yesOrNo;

  /// No description provided for @everyXDays.
  ///
  /// In en, this message translates to:
  /// **'Every {p1} days'**
  String everyXDays(int p1);

  /// No description provided for @everyXWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {p1} weeks'**
  String everyXWeeks(int p1);

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @reminderSound.
  ///
  /// In en, this message translates to:
  /// **'Reminder sound'**
  String get reminderSound;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @hideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Hide completed'**
  String get hideCompleted;

  /// No description provided for @hideEntered.
  ///
  /// In en, this message translates to:
  /// **'Hide entered'**
  String get hideEntered;

  /// No description provided for @hideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get hideArchived;

  /// No description provided for @stickyNotifications.
  ///
  /// In en, this message translates to:
  /// **'Make notifications sticky'**
  String get stickyNotifications;

  /// No description provided for @stickyNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Prevents notifications from being swiped away.'**
  String get stickyNotificationsDescription;

  /// No description provided for @ledNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notification light'**
  String get ledNotifications;

  /// No description provided for @ledNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows a blinking light for reminders. Only available in phones with LED notification lights.'**
  String get ledNotificationsDescription;

  /// No description provided for @repairDatabase.
  ///
  /// In en, this message translates to:
  /// **'Repair database'**
  String get repairDatabase;

  /// No description provided for @databaseRepaired.
  ///
  /// In en, this message translates to:
  /// **'Database repaired.'**
  String get databaseRepaired;

  /// No description provided for @uncheck.
  ///
  /// In en, this message translates to:
  /// **'Uncheck'**
  String get uncheck;

  /// No description provided for @toggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get toggle;

  /// No description provided for @action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @habit.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get habit;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @manually.
  ///
  /// In en, this message translates to:
  /// **'Manually'**
  String get manually;

  /// No description provided for @byName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get byName;

  /// No description provided for @byColor.
  ///
  /// In en, this message translates to:
  /// **'By color'**
  String get byColor;

  /// No description provided for @byScore.
  ///
  /// In en, this message translates to:
  /// **'By score'**
  String get byScore;

  /// No description provided for @byStatus.
  ///
  /// In en, this message translates to:
  /// **'By status'**
  String get byStatus;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @longPressToEdit.
  ///
  /// In en, this message translates to:
  /// **'Press-and-hold to change the value'**
  String get longPressToEdit;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @targetType.
  ///
  /// In en, this message translates to:
  /// **'Target Type'**
  String get targetType;

  /// No description provided for @targetTypeAtLeast.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get targetTypeAtLeast;

  /// No description provided for @targetTypeAtMost.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get targetTypeAtMost;

  /// No description provided for @exampleQuestionBoolean.
  ///
  /// In en, this message translates to:
  /// **'e.g. Did you exercise today?'**
  String get exampleQuestionBoolean;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @customizeNotificationSummary.
  ///
  /// In en, this message translates to:
  /// **'Change sound, vibration, light and other notification settings'**
  String get customizeNotificationSummary;

  /// No description provided for @customizeNotification.
  ///
  /// In en, this message translates to:
  /// **'Customize notifications'**
  String get customizeNotification;

  /// No description provided for @prefViewPrivacy.
  ///
  /// In en, this message translates to:
  /// **'View privacy policy'**
  String get prefViewPrivacy;

  /// No description provided for @viewAllContributors.
  ///
  /// In en, this message translates to:
  /// **'View all contributors…'**
  String get viewAllContributors;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @widgetOpacityTitle.
  ///
  /// In en, this message translates to:
  /// **'Widget opacity'**
  String get widgetOpacityTitle;

  /// No description provided for @widgetOpacityDescription.
  ///
  /// In en, this message translates to:
  /// **'Makes widgets more transparent or more opaque in your home screen.'**
  String get widgetOpacityDescription;

  /// No description provided for @firstDayOfTheWeek.
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get firstDayOfTheWeek;

  /// No description provided for @defaultReminderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Have you completed this habit today?'**
  String get defaultReminderQuestion;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @exampleNotes.
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get exampleNotes;

  /// No description provided for @yesOrNoExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Did you wake up early today? Did you exercise? Did you play chess?'**
  String get yesOrNoExample;

  /// No description provided for @measurable.
  ///
  /// In en, this message translates to:
  /// **'Measurable'**
  String get measurable;

  /// No description provided for @measurableExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. How many miles did you run today? How many pages did you read?'**
  String get measurableExample;

  /// No description provided for @xTimesPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{p1} times per week'**
  String xTimesPerWeek(int p1);

  /// No description provided for @xTimesPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{p1} times per month'**
  String xTimesPerMonth(int p1);

  /// No description provided for @xTimesPerYDays.
  ///
  /// In en, this message translates to:
  /// **'{p1} times in {p2} days'**
  String xTimesPerYDays(int p1, int p2);

  /// No description provided for @yesOrNoShortExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Exercise'**
  String get yesOrNoShortExample;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @exampleTarget.
  ///
  /// In en, this message translates to:
  /// **'e.g. 15'**
  String get exampleTarget;

  /// No description provided for @measurableShortExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Run'**
  String get measurableShortExample;

  /// No description provided for @measurableQuestionExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. How many miles did you run today?'**
  String get measurableQuestionExample;

  /// No description provided for @measurableUnitsExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. miles'**
  String get measurableUnitsExample;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @validationCannotBeBlank.
  ///
  /// In en, this message translates to:
  /// **'Cannot be blank'**
  String get validationCannotBeBlank;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @enter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get enter;

  /// No description provided for @noHabits.
  ///
  /// In en, this message translates to:
  /// **'No habits found'**
  String get noHabits;

  /// No description provided for @noNumericalHabits.
  ///
  /// In en, this message translates to:
  /// **'No measurable habits found'**
  String get noNumericalHabits;

  /// No description provided for @noBooleanHabits.
  ///
  /// In en, this message translates to:
  /// **'No yes-or-no habits found'**
  String get noBooleanHabits;

  /// No description provided for @increment.
  ///
  /// In en, this message translates to:
  /// **'Increment'**
  String get increment;

  /// No description provided for @decrement.
  ///
  /// In en, this message translates to:
  /// **'Decrement'**
  String get decrement;

  /// No description provided for @prefSkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable skip days'**
  String get prefSkipTitle;

  /// No description provided for @skipDay.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipDay;

  /// No description provided for @prefSkipDescription.
  ///
  /// In en, this message translates to:
  /// **'Toggle twice to add a skip instead of a checkmark. Skips keep your score unchanged and don\'t break your streak.'**
  String get prefSkipDescription;

  /// No description provided for @prefUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Show question marks for missing data'**
  String get prefUnknownTitle;

  /// No description provided for @prefUnknownDescription.
  ///
  /// In en, this message translates to:
  /// **'Differentiate days without data from actual lapses. To enter a lapse, toggle twice.'**
  String get prefUnknownDescription;

  /// No description provided for @youAreNowADeveloper.
  ///
  /// In en, this message translates to:
  /// **'You are now a developer'**
  String get youAreNowADeveloper;

  /// No description provided for @activityNotFound.
  ///
  /// In en, this message translates to:
  /// **'No app was found to support this action'**
  String get activityNotFound;

  /// No description provided for @prefMidnightDelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Extend day a few hours past midnight'**
  String get prefMidnightDelayTitle;

  /// No description provided for @prefMidnightDelayDescription.
  ///
  /// In en, this message translates to:
  /// **'Wait until 3:00 AM to show a new day. Useful if you typically go to sleep after midnight. Requires app restart.'**
  String get prefMidnightDelayDescription;

  /// No description provided for @prefAnimationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable animations'**
  String get prefAnimationsTitle;

  /// No description provided for @prefAnimationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Disable confetti animation after adding a checkmark.'**
  String get prefAnimationsDescription;

  /// No description provided for @toastHabitsChanged.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Habit changed} other {Habits changed}}'**
  String toastHabitsChanged(num count);

  /// No description provided for @toastHabitsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Habit deleted} other {Habits deleted}}'**
  String toastHabitsDeleted(num count);

  /// No description provided for @toastHabitsArchived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Habit archived} other {Habits archived}}'**
  String toastHabitsArchived(num count);

  /// No description provided for @toastHabitsUnarchived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Habit unarchived} other {Habits unarchived}}'**
  String toastHabitsUnarchived(num count);

  /// No description provided for @deleteHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Delete habit?} other {Delete habits?}}'**
  String deleteHabitsTitle(num count);

  /// No description provided for @deleteHabitsMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {The habit will be permanently deleted. This action cannot be undone.} other {The habits will be permanently deleted. This action cannot be undone.}}'**
  String deleteHabitsMessage(num count);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'ar',
    'bg',
    'ca',
    'cs',
    'da',
    'de',
    'el',
    'en',
    'eo',
    'es',
    'eu',
    'fa',
    'fi',
    'fr',
    'gu',
    'he',
    'hi',
    'hr',
    'hu',
    'hy',
    'id',
    'is',
    'it',
    'ja',
    'ka',
    'ko',
    'ml',
    'nl',
    'no',
    'pl',
    'pt',
    'ro',
    'ru',
    'sk',
    'sl',
    'sr',
    'sv',
    'ta',
    'te',
    'tr',
    'ug',
    'uk',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Latn':
            return L10nSrLatn();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return L10nPtBr();
          case 'PT':
            return L10nPtPt();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return L10nZhCn();
          case 'TW':
            return L10nZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return L10nAf();
    case 'ar':
      return L10nAr();
    case 'bg':
      return L10nBg();
    case 'ca':
      return L10nCa();
    case 'cs':
      return L10nCs();
    case 'da':
      return L10nDa();
    case 'de':
      return L10nDe();
    case 'el':
      return L10nEl();
    case 'en':
      return L10nEn();
    case 'eo':
      return L10nEo();
    case 'es':
      return L10nEs();
    case 'eu':
      return L10nEu();
    case 'fa':
      return L10nFa();
    case 'fi':
      return L10nFi();
    case 'fr':
      return L10nFr();
    case 'gu':
      return L10nGu();
    case 'he':
      return L10nHe();
    case 'hi':
      return L10nHi();
    case 'hr':
      return L10nHr();
    case 'hu':
      return L10nHu();
    case 'hy':
      return L10nHy();
    case 'id':
      return L10nId();
    case 'is':
      return L10nIs();
    case 'it':
      return L10nIt();
    case 'ja':
      return L10nJa();
    case 'ka':
      return L10nKa();
    case 'ko':
      return L10nKo();
    case 'ml':
      return L10nMl();
    case 'nl':
      return L10nNl();
    case 'no':
      return L10nNo();
    case 'pl':
      return L10nPl();
    case 'pt':
      return L10nPt();
    case 'ro':
      return L10nRo();
    case 'ru':
      return L10nRu();
    case 'sk':
      return L10nSk();
    case 'sl':
      return L10nSl();
    case 'sr':
      return L10nSr();
    case 'sv':
      return L10nSv();
    case 'ta':
      return L10nTa();
    case 'te':
      return L10nTe();
    case 'tr':
      return L10nTr();
    case 'ug':
      return L10nUg();
    case 'uk':
      return L10nUk();
    case 'vi':
      return L10nVi();
    case 'zh':
      return L10nZh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
