// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class L10nHe extends L10n {
  L10nHe([String locale = 'he']) : super(locale);

  @override
  String get overview => 'מבט על';

  @override
  String get appName => '‏Loop לניהול הרגלים';

  @override
  String get mainActivityTitle => 'הרגלים';

  @override
  String get actionSettings => 'הגדרות';

  @override
  String get edit => 'עריכה';

  @override
  String get delete => 'מחיקה';

  @override
  String get archive => 'העברה לארכיון';

  @override
  String get unarchive => 'הוצאה מהארכיון';

  @override
  String get addHabit => 'הרגל חדש';

  @override
  String get colorPickerDefaultTitle => 'שינוי צבע';

  @override
  String get toastHabitCreated => 'ההרגל נוצר';

  @override
  String get habitStrength => 'חוזק ההרגל';

  @override
  String get history => 'היסטוריה';

  @override
  String get clear => 'ניקוי';

  @override
  String get reminder => 'תזכורת';

  @override
  String get save => 'שמירה';

  @override
  String get streaks => 'שיאים';

  @override
  String get noHabitsFound => 'אין לך הרגלים פעילים';

  @override
  String get noHabitsLeftToDo => 'זהו להיום!';

  @override
  String get longPressToToggle => 'לחיצה ארוכה תסמן או תבטל את הסימון';

  @override
  String get reminderOff => 'כבוי';

  @override
  String get createHabit => 'יצירת הרגל';

  @override
  String get editHabit => 'עריכת הרגל';

  @override
  String get check => 'סימון';

  @override
  String get snooze => 'מאוחר יותר';

  @override
  String get introTitle1 => 'ברוך בואך';

  @override
  String get introDescription1 =>
      '‏”Loop לניהול הרגלים“ מסייע לך להתחיל ולשמר הרגלים טובים.';

  @override
  String get introTitle2 => 'יצירת הרגלים חדשים';

  @override
  String get introDescription2 =>
      'בכל יום, לאחר ביצוע ההרגל, מסמנים את זה ביישום.';

  @override
  String get introTitle4 => 'מעקב אחר ההתקדמות';

  @override
  String get introDescription4 =>
      'גרפים מפורטים מציגים את השתפרות ההרגלים לאורך זמן.';

  @override
  String get interval15Minutes => 'רבע שעה';

  @override
  String get interval30Minutes => 'חצי שעה';

  @override
  String get interval1Hour => 'שעה';

  @override
  String get interval2Hour => 'שעתיים';

  @override
  String get interval4Hour => '4 שעות';

  @override
  String get interval8Hour => '8 שעות';

  @override
  String get interval24Hour => '24 שעות';

  @override
  String get intervalAlwaysAsk => 'תמיד לשאול';

  @override
  String get intervalCustom => 'התאמה אישית...';

  @override
  String get prefToggleTitle => 'סימון הרגלים בלחיצה קצרה';

  @override
  String get prefToggleDescription2 =>
      'סימון הרגלים בלחיצה פשוטה במקום לחיצה והחזקה.';

  @override
  String get prefRateThisApp => 'דירוג היישום ב־Google Play';

  @override
  String get prefSendFeedback => 'שליחת משוב למפתח';

  @override
  String get prefViewSourceCode => 'צפייה בקוד המקור ב־GitHub';

  @override
  String get links => 'קישורים';

  @override
  String get name => 'שם';

  @override
  String get settings => 'הגדרות';

  @override
  String get selectSnoozeDelay => 'נא לבחור בכמה זמן לדחות את התזכורת';

  @override
  String get hintTitle => 'הידעת?';

  @override
  String get hintDrag =>
      'אפשר לשנות את סדר ההרגלים בעזרת לחיצה ארוכה על הרגל וגרירתו למקום הרצוי.';

  @override
  String get hintLandscape => 'אפשר לסובב את המסך לרוחב ולראות ימים נוספים.';

  @override
  String get habitNotFound => 'ההרגל נמחק / לא נמצא';

  @override
  String get weekends => 'שבת וראשון';

  @override
  String get anyWeekday => 'שני עד שישי';

  @override
  String get anyDay => 'כל ימות השבוע';

  @override
  String get selectWeekdays => 'בחירת ימים';

  @override
  String get exportToCsv => 'ייצוא כקובץ CSV';

  @override
  String get doneLabel => 'סיום';

  @override
  String get clearLabel => 'ניקוי';

  @override
  String get selectHours => 'בחירת שעות';

  @override
  String get selectMinutes => 'בחירת דקות';

  @override
  String get about => 'מידע כללי';

  @override
  String get translators => 'תרגום';

  @override
  String get developers => 'פיתוח';

  @override
  String versionN(String p1) {
    return 'גרסה $p1';
  }

  @override
  String get frequency => 'תדירות';

  @override
  String get checkmark => 'סימון הרגל';

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
  String get bestStreaks => 'שיאי התמדה';

  @override
  String get everyDay => 'כל יום';

  @override
  String get everyWeek => 'כל שבוע';

  @override
  String get help => 'עזרה ושאלות נפוצות';

  @override
  String get couldNotExport => 'ייצוא הנתונים נכשל.';

  @override
  String get couldNotImport => 'ייבוא הנתונים נכשל.';

  @override
  String get fileNotRecognized => 'קובץ לא מזוהה.';

  @override
  String get habitsImported => 'ייבוא ההרגלים הצליח.';

  @override
  String get importData => 'ייבוא נתונים';

  @override
  String get exportFullBackup => 'ייצוא גיבוי מלא';

  @override
  String get importDataSummary =>
      'יש תמיכה בכל הגיבויים שיוצאו מיישום זה, וגם בקבצים שנוצרו על ידי Tickmate, ‏HabitBull או Rewire. למידע נוסף נא לעיין בשאלות הנפוצות.';

  @override
  String get exportAsCsvSummary =>
      'ליצירת קבצים שנפתחים בתוכנת גיליונות אלקטרוניים כמו Microsoft Exel או OpenOffice Calc. לא ניתן לייבא את הקובץ בחזרה.';

  @override
  String get exportFullBackupSummary =>
      'ליצירת קובץ שמכיל את כל הנתונים שלך. לא ניתן לייבא את הקובץ בחזרה.';

  @override
  String get selectPublicBackupFolder => 'בחר תיקיית גיבוי ציבורית';

  @override
  String get noPublicBackupFolderSelected => 'לא נבחרה תיקיה';

  @override
  String get bugReportFailed => 'יצירת דו״ח התקלה נכשלה.';

  @override
  String get generateBugReport => 'יצירת דו״ח תקלה';

  @override
  String get troubleshooting => 'פתרון תקלות';

  @override
  String get helpTranslate => 'סיוע בתרגום היישום';

  @override
  String get nightMode => 'ערכת נושא כהה';

  @override
  String get usePureBlack => 'רקע שחור מוחלט בערכת הנושא הכהה';

  @override
  String get pureBlackDescription =>
      'החלפת הרקע האפור בערכת הנושא הכהה לשחור מוחלט. מפחית את צריכת הסוללה במכשירים עם תצוגת AMOLED.';

  @override
  String get interfacePreferences => 'ממשק';

  @override
  String get reverseDays => 'סדר ימים הפוך';

  @override
  String get reverseDaysDescription => 'הצגת הימים בסדר הפוך במסך הראשי.';

  @override
  String get day => 'יום';

  @override
  String get week => 'שבוע';

  @override
  String get month => 'חודש';

  @override
  String get quarter => 'רבעון';

  @override
  String get year => 'שנה';

  @override
  String get total => 'סה״כ';

  @override
  String get yesOrNo => 'כן או לא';

  @override
  String everyXDays(int p1) {
    return 'כל $p1 ימים';
  }

  @override
  String everyXWeeks(int p1) {
    return 'כל $p1 שבועות';
  }

  @override
  String get score => 'ציון';

  @override
  String get reminderSound => 'צליל תזכורת';

  @override
  String get none => 'ללא';

  @override
  String get filter => 'סינון';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'הסתרת יעדים שהושגו';

  @override
  String get hideEntered => 'הסתרת ההרגלים שסומנו';

  @override
  String get hideArchived => 'הסתרת הארכיון';

  @override
  String get stickyNotifications => 'הצמדת כל ההתראות';

  @override
  String get stickyNotificationsDescription => 'למניעת התעלמות מתזכורות.';

  @override
  String get ledNotifications => 'תאורת התראה';

  @override
  String get ledNotificationsDescription =>
      'להצגת אור מהבהב לתזכורות. התכונה זמינה רק בטלפונים עם נורות LED להתראות.';

  @override
  String get repairDatabase => 'תיקון מסד הנתונים';

  @override
  String get databaseRepaired => 'מסד הנתונים תוקן.';

  @override
  String get uncheck => 'ביטול הסימון';

  @override
  String get toggle => 'סימון או ביטול הסימון';

  @override
  String get action => 'פעולה';

  @override
  String get habit => 'הרגל';

  @override
  String get sort => 'מיון';

  @override
  String get manually => 'באופן ידני';

  @override
  String get byName => 'לפי שם';

  @override
  String get byColor => 'לפי צבע';

  @override
  String get byScore => 'לפי ציון';

  @override
  String get byStatus => 'לפי מצב';

  @override
  String get export => 'ייצוא';

  @override
  String get longPressToEdit => 'לחיצה ארוכה תשנה את הערך';

  @override
  String get value => 'ערך';

  @override
  String get calendar => 'לוח שנה';

  @override
  String get unit => 'יחידה';

  @override
  String get targetType => 'סוג יעד';

  @override
  String get targetTypeAtLeast => 'לכל הפחות';

  @override
  String get targetTypeAtMost => 'לכל היותר';

  @override
  String get exampleQuestionBoolean => 'למשל: עשית כושר היום?';

  @override
  String get question => 'שאלה';

  @override
  String get target => 'יעד';

  @override
  String get yes => 'כן';

  @override
  String get no => 'לא';

  @override
  String get customizeNotificationSummary =>
      'שינוי הצליל, הרטט, התאורה והגדרות התראה אחרות';

  @override
  String get customizeNotification => 'אפשרויות התראה';

  @override
  String get prefViewPrivacy => 'צפייה במדיניות הפרטיות';

  @override
  String get viewAllContributors => 'הצגת כל המתנדבים…';

  @override
  String get database => 'מסד נתונים';

  @override
  String get widgetOpacityTitle => 'אטימות היישומונים';

  @override
  String get widgetOpacityDescription =>
      'הפיכת היישומונים במסך הבית לשקופים או אטומים יותר.';

  @override
  String get firstDayOfTheWeek => 'היום הראשון בשבוע';

  @override
  String get defaultReminderQuestion => 'השלמת את ההרגל הזה היום?';

  @override
  String get notes => 'הערות';

  @override
  String get exampleNotes => '(רשות)';

  @override
  String get yesOrNoExample =>
      'למשל: התעוררת מוקדם היום? עשית כושר? שיחקת שחמט?';

  @override
  String get measurable => 'הרגלים נמדדים';

  @override
  String get measurableExample =>
      'למשל: כמה קילומטרים רצת היום? כמה עמודים קראת?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 פעמים בשבוע';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 פעמים בחודש';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 פעמים ב־$p2 ימים';
  }

  @override
  String get yesOrNoShortExample => 'למשל: פעילות גופנית';

  @override
  String get color => 'צבע';

  @override
  String get exampleTarget => 'למשל: 15';

  @override
  String get measurableShortExample => 'למשל: ריצה';

  @override
  String get measurableQuestionExample => 'למשל: כמה קילומטרים רצת היום?';

  @override
  String get measurableUnitsExample => 'למשל: קילומטרים';

  @override
  String get everyMonth => 'כל חודש';

  @override
  String get validationCannotBeBlank => 'זהו שדה חובה';

  @override
  String get today => 'היום';

  @override
  String get enter => 'מילוי';

  @override
  String get noHabits => 'לא נמצאו הרגלים';

  @override
  String get noNumericalHabits => 'לא נמצאו הרגלים נמדדים';

  @override
  String get noBooleanHabits => 'לא נמצאו הרגלי ”כן או לא“';

  @override
  String get increment => 'עלייה';

  @override
  String get decrement => 'ירידה';

  @override
  String get prefSkipTitle => 'לאפשר דילוג על ימים';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'סימון כפול כדי לדלג במקום לסמן. הדילוג שומר על הציון שלך ללא שינוי ואינו שובר את הרצף שלך.';

  @override
  String get prefUnknownTitle => 'הצגת סימני שאלה לנתונים חסרים';

  @override
  String get prefUnknownDescription =>
      'הפרדת הימים ללא הנתונים מהלולאות בפועל. כדי להיכנס ללולאה, יש לסמן פעמיים.';

  @override
  String get youAreNowADeveloper => 'מצב הפיתוח הופעל כעת';

  @override
  String get activityNotFound => 'לא נמצא יישום שתומך בפעולה זו';

  @override
  String get prefMidnightDelayTitle => 'הארכת היום בכמה שעות לאחר החצות';

  @override
  String get prefMidnightDelayDescription =>
      'המתנה עד 3:00 לפני הצגת יום חדש. שימושי אם לרוב הולכים לישון אחרי חצות. דורש הפעלה מחדש של היישום.';

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
      other: 'ההרגלים שונו',
      many: 'ההרגלים שונו',
      two: 'ההרגלים שונו',
      one: 'ההרגל שוּנה',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ההרגלים נמחקו',
      many: 'ההרגלים נמחקו',
      two: 'ההרגלים נמחקו',
      one: 'ההרגל נמחק',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ההרגלים הועברו לארכיון',
      many: 'ההרגלים הועברו לארכיון',
      two: 'ההרגלים הועברו לארכיון',
      one: 'ההרגל הועבר לארכיון',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ההרגלים הוצאו מארכיון',
      many: 'ההרגלים הוצאו מארכיון',
      two: 'ההרגלים הוצאו מארכיון',
      one: 'ההרגל הוצא מהארכיון',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'למחוק את ההרגלים?',
      many: 'למחוק את ההרגלים?',
      two: 'למחוק את ההרגלים?',
      one: 'למחוק את ההרגל?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ההרגלים יימחקו לצמיתות. לא ניתן לבטל פעולה זו.',
      many: 'ההרגלים יימחקו לצמיתות. לא ניתן לבטל פעולה זו.',
      two: 'ההרגלים יימחקו לצמיתות. לא ניתן לבטל פעולה זו.',
      one: 'ההרגל יימחק לצמיתות. לא ניתן לבטל פעולה זו.',
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
