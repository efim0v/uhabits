// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get overview => 'نظرة عامة';

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'عادات';

  @override
  String get actionSettings => 'إعدادات';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get archive => 'أرشيف';

  @override
  String get unarchive => 'إزالة من الأرشيف';

  @override
  String get addHabit => 'إضافة عادة';

  @override
  String get colorPickerDefaultTitle => 'تغيير اللون';

  @override
  String get toastHabitCreated => 'تم إنشاء عادة';

  @override
  String get habitStrength => 'قوة العادة';

  @override
  String get history => 'السجل';

  @override
  String get clear => 'إزالة';

  @override
  String get reminder => 'تذكير';

  @override
  String get save => 'حفظ';

  @override
  String get streaks => 'الإنجازات';

  @override
  String get noHabitsFound => 'لا يوجد لديك عادات مفعله';

  @override
  String get noHabitsLeftToDo => 'لقد أنهيت ألعمل لليوم';

  @override
  String get longPressToToggle => 'اضغط باستمرار للتأكيد أو الإزالة.';

  @override
  String get reminderOff => 'إيقاف';

  @override
  String get createHabit => 'انشاء العادة';

  @override
  String get editHabit => 'تعديل العادة';

  @override
  String get check => 'سجل';

  @override
  String get snooze => 'لاحقاً';

  @override
  String get introTitle1 => 'أهلا بك';

  @override
  String get introDescription1 =>
      'يساعدك متتبع العادات loop في بَدْء عادات جيدة والحفاظ عليها.';

  @override
  String get introTitle2 => 'إنشاء بعض عادات جديدة';

  @override
  String get introDescription2 =>
      'كل يوم، بعد أداء عادتك، ضع علامة عليها في التطبيق.';

  @override
  String get introTitle4 => 'تتبع تقدمك';

  @override
  String get introDescription4 =>
      'رسوم بيانية مفصلة تُريك كيف تحسنت عاداتك مع مرور الوقت.';

  @override
  String get interval15Minutes => '15 دقيقة';

  @override
  String get interval30Minutes => '30 دقيقة';

  @override
  String get interval1Hour => 'ساعة واحدة';

  @override
  String get interval2Hour => 'ساعتان';

  @override
  String get interval4Hour => '٤ ساعات';

  @override
  String get interval8Hour => '٨ ساعات';

  @override
  String get interval24Hour => '٢٤ ساعة';

  @override
  String get intervalAlwaysAsk => 'اسأل دائماً';

  @override
  String get intervalCustom => 'مخصص...';

  @override
  String get prefToggleTitle => 'تبديل وضعية العادة بضغطة قصيرة';

  @override
  String get prefToggleDescription2 =>
      'ضع علامات اختيار بنقرة واحدة بدلاً من الضغط مع الاستمرار.';

  @override
  String get prefRateThisApp => 'تقييم هذا التطبيق على جوجل بلاي';

  @override
  String get prefSendFeedback => 'أرسل الملاحظات إلى المطور';

  @override
  String get prefViewSourceCode => 'إفحص التعليمات البرمجية على GitHub';

  @override
  String get links => 'روابط';

  @override
  String get name => 'الاسم';

  @override
  String get settings => 'إعدادات';

  @override
  String get selectSnoozeDelay => 'حدد تأخير الغفوة';

  @override
  String get hintTitle => 'هل كنت تعلم؟';

  @override
  String get hintDrag =>
      'لإعادة ترتيب القوائم، أضغط اسم من هذه العادة، ثم اسحبه إلى المكان الصحيح.';

  @override
  String get hintLandscape =>
      'يمكنك ان ترى المزيد أيام عن طريق وضع الهاتف في وضع أفقي.';

  @override
  String get habitNotFound => 'العادة حذفت/لم يتم العثور عليها';

  @override
  String get weekends => 'عطلة نهاية الأسبوع';

  @override
  String get anyWeekday => 'أيام الأسبوع.';

  @override
  String get anyDay => 'أي يوم.';

  @override
  String get selectWeekdays => 'إختار أيام';

  @override
  String get exportToCsv => 'تصدير البيانات (CSV)';

  @override
  String get doneLabel => 'إنهاء';

  @override
  String get clearLabel => 'نظف';

  @override
  String get selectHours => 'تحديد ساعات';

  @override
  String get selectMinutes => 'تحديد دقائق';

  @override
  String get about => 'معلومات حول';

  @override
  String get translators => 'المترجمين';

  @override
  String get developers => 'المطورين';

  @override
  String versionN(String p1) {
    return 'الإصدار $p1';
  }

  @override
  String get frequency => 'تردد';

  @override
  String get checkmark => 'علامة الاختيار';

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
  String get bestStreaks => 'أكثر تقدم';

  @override
  String get everyDay => 'كل يوم';

  @override
  String get everyWeek => 'كل اسبوع';

  @override
  String get help => 'مساعدة والأسئلة المتداولة';

  @override
  String get couldNotExport => 'فشل في تصدير البيانات.';

  @override
  String get couldNotImport => 'فشل في استيراد البيانات.';

  @override
  String get fileNotRecognized => 'لم يتم التعرف على الملف.';

  @override
  String get habitsImported => 'نجح إستيراد العادات.';

  @override
  String get importData => 'استيراد بيانات.';

  @override
  String get exportFullBackup => 'صدر نسخة احتياطية كاملة.';

  @override
  String get importDataSummary =>
      'تدعم النسخ الاحتياطي الكامل المصدرة من هذا التطبيق، فضلا عن الملفات التي تم إنشاؤها من Tickmate, HabitBull و Rewire. انظر التعليمات لمزيد من المعلومات.';

  @override
  String get exportAsCsvSummary =>
      'صدر ملف التي يمكن فتحها ببرنامج جداول البيانات مثل إكسل أو وبينوفيس. لا يمكن إستيراد هذا الملف.';

  @override
  String get exportFullBackupSummary =>
      'إنشاء ملف يحتوي على كافة البيانات. يمكن استيراد هذا الملف نفسه.';

  @override
  String get selectPublicBackupFolder => 'اختر مجلد النسخ الاحتياطي العام';

  @override
  String get noPublicBackupFolderSelected => 'لم يتم اختيار مجلد';

  @override
  String get bugReportFailed => 'فشل في توليد تقرير الاعطال';

  @override
  String get generateBugReport => 'توليد تقرير الاعطال.';

  @override
  String get troubleshooting => 'استكشاف الأخطاء وإصلاحها.';

  @override
  String get helpTranslate => 'المساعدة في ترجمة هذا البرنامج.';

  @override
  String get nightMode => 'الوضع الليلي';

  @override
  String get usePureBlack => 'استخدام أسود نقي في الوضع الليلي.';

  @override
  String get pureBlackDescription =>
      'يستبدل خلفيات رمادية مع أسود نقي في الوضع الليلي. يقلل من استهلاك البطارية في الهواتف مع شاشة AMOLED. .';

  @override
  String get interfacePreferences => 'السطح البيني.';

  @override
  String get reverseDays => 'ترتيب عكسي أيام.';

  @override
  String get reverseDaysDescription =>
      'عرض أيام في ترتيب عكسي على الشاشة الرئيسية.';

  @override
  String get day => 'يوم';

  @override
  String get week => 'أسبوع.';

  @override
  String get month => 'شهر.';

  @override
  String get quarter => 'ربع سنه.';

  @override
  String get year => 'عام';

  @override
  String get total => 'المجموع.';

  @override
  String get yesOrNo => 'نعم أو لا';

  @override
  String everyXDays(int p1) {
    return 'كل $p1 أيام';
  }

  @override
  String everyXWeeks(int p1) {
    return 'كل $p1 أسابيع';
  }

  @override
  String get score => 'النقاط';

  @override
  String get reminderSound => 'صوت تذكير';

  @override
  String get none => 'صامت';

  @override
  String get filter => 'تصنيف';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'إخفاء المكتملة';

  @override
  String get hideEntered => 'إخفاء المُدخل';

  @override
  String get hideArchived => 'إخفاء المؤرشفة';

  @override
  String get stickyNotifications => 'جعل الإشعارات ثابتة';

  @override
  String get stickyNotificationsDescription =>
      'منع الإشعارات من تمريرها بعيداً.';

  @override
  String get ledNotifications => 'ضوء الإشعارات';

  @override
  String get ledNotificationsDescription =>
      'إظهار ضوء وامض للتذكيرات. متوفر فقط في الهواتف المزودة بمصابيح إشعارات LED.';

  @override
  String get repairDatabase => 'إصلاح قاعدة البيانات';

  @override
  String get databaseRepaired => 'تم إصلاح قاعدة البيانات.';

  @override
  String get uncheck => 'إلغاء تحديد';

  @override
  String get toggle => 'تبديل';

  @override
  String get action => 'عمل';

  @override
  String get habit => 'عادة';

  @override
  String get sort => 'فرز';

  @override
  String get manually => 'يدوياً';

  @override
  String get byName => 'حسب الإسم';

  @override
  String get byColor => 'حسب اللون';

  @override
  String get byScore => 'حسب النقاط';

  @override
  String get byStatus => 'حسب الحالة';

  @override
  String get export => 'استخراج';

  @override
  String get longPressToEdit => 'اضغط مع الاستمرار لتغيرالقيمه';

  @override
  String get value => 'القيمة';

  @override
  String get calendar => 'التقويم';

  @override
  String get unit => 'الوحدة';

  @override
  String get targetType => 'نوع الهدف';

  @override
  String get targetTypeAtLeast => 'على الأقل';

  @override
  String get targetTypeAtMost => 'على الأكثر';

  @override
  String get exampleQuestionBoolean => 'على سبيل المثال هل تمرنت اليوم؟';

  @override
  String get question => 'السؤال';

  @override
  String get target => 'الهدف';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get customizeNotificationSummary =>
      'Change sound, vibration, light and other notification settings';

  @override
  String get customizeNotification => 'Customize notifications';

  @override
  String get prefViewPrivacy => 'عرض نهج الخصوصية';

  @override
  String get viewAllContributors => 'عرض جميع المساهمين…';

  @override
  String get database => 'قاعدة البيانات';

  @override
  String get widgetOpacityTitle => 'شفافية اختصار الشاشة الرئيسية';

  @override
  String get widgetOpacityDescription =>
      'Makes widgets more transparent or more opaque in your home screen.';

  @override
  String get firstDayOfTheWeek => 'اليوم الأول من الأسبوع';

  @override
  String get defaultReminderQuestion => 'هل أكملت هذه العادة اليوم؟';

  @override
  String get notes => 'ملاحظات';

  @override
  String get exampleNotes => '(اختياري)';

  @override
  String get yesOrNoExample =>
      'مثلا: هل استيقظت باكرا اليوم؟ هل مارست الرياضة؟ هل لعبت الشطرنج؟';

  @override
  String get measurable => 'قابل للقياس';

  @override
  String get measurableExample =>
      'مثال، كم ميلاً قطعته اليوم؟ كم عدد الصفحات التي قرأتها؟';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 مرة في الأسبوع';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 مرة في الشهر';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 مرات في $p2 أيام';
  }

  @override
  String get yesOrNoShortExample => 'مثال: التمرين';

  @override
  String get color => 'اللون';

  @override
  String get exampleTarget => 'مثال: 15';

  @override
  String get measurableShortExample => 'مثلا: الجري';

  @override
  String get measurableQuestionExample => 'مثلا، كم ميلا ركضت اليوم؟';

  @override
  String get measurableUnitsExample => 'مثلا: كيلومترات';

  @override
  String get everyMonth => 'كل شهر';

  @override
  String get validationCannotBeBlank => 'لا يمكن أن يكون الإسم فارغًا';

  @override
  String get today => 'اليوم';

  @override
  String get enter => 'ادخل';

  @override
  String get noHabits => 'لا توجد عادات';

  @override
  String get noNumericalHabits => 'لا توجد عادات قابلة للقياس';

  @override
  String get noBooleanHabits => 'لا توجد عادات تجاوب بنعم أو لا';

  @override
  String get increment => 'زيادة';

  @override
  String get decrement => 'إنقاص';

  @override
  String get prefSkipTitle => 'تمكين أيام التخطي';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'بدّل مرتين لإضافة تخطي بدلاً من علامة اختيار. التخطيات تحافظ على درجاتك دون تغيير أو خسارة سلسلة الانتصارات.';

  @override
  String get prefUnknownTitle => 'إظهار علامات الاستفهام للبيانات المفقودة';

  @override
  String get prefUnknownDescription =>
      'التفريق بين الأيام التي لا تحتوي على بيانات من الهفوات الفعلية. للدخول في اللقطات المتتابعة ، قم بالتبديل مرتين.';

  @override
  String get youAreNowADeveloper => 'أنت الآن مطوَِر برمجيات!';

  @override
  String get activityNotFound => 'لم يتم العثور على تطبيق لإتمام هذا الإجراء';

  @override
  String get prefMidnightDelayTitle => 'تمديد اليوم بضع ساعات بعد منتصف الليل';

  @override
  String get prefMidnightDelayDescription =>
      'انتظر حتى 3:00 صباحاً لعرض يوم جديد. مفيد إذا كنت عادة تذهب إلى السكون بعد منتصف الليل. يتطلب إعادة تشغيل التطبيق.';

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
      other: 'تم تغيير العادات',
      many: 'تم تغيير العادات',
      few: 'تم تغيير العادات',
      two: 'تم تغيير العادتين',
      one: 'تم تغيير العادة',
      zero: 'تم تغيير العادة',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف العادات',
      many: 'تم حذف العادات',
      few: 'تم حذف العادات',
      two: 'تم حذف العادتين',
      one: 'تم حذف العادة',
      zero: 'تم حذف العادة',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت أرشفة العادات',
      many: 'تمت أرشفة العادات',
      few: 'تمت أرشفة العادات',
      two: 'تمت أرشفة العادتين',
      one: 'تم أرشفه العادة',
      zero: 'تمت أرشفة العادة',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم إلغاء أرشفة العادة',
      many: 'تم إلغاء أرشفة العادات',
      few: 'تم إلغاء أرشفة العادات',
      two: 'تم إلغاء أرشفة العادتين',
      one: 'تم الغاء ارشفه العادة',
      zero: 'تم الغاء ارشفه العادة',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف العادات؟',
      many: 'حذف العادات؟',
      few: 'حذف العادات؟',
      two: 'حذف العادتين؟',
      one: 'حذف العادة؟',
      zero: 'حذف العادة؟',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيتم حذف العادات بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
      many: 'سيتم حذف العادات بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
      few: 'سيتم حذف العادات بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
      two: 'سيتم حذف العادتين بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
      one: 'سيتم حذف العادة بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
      zero: 'سيتم حذف العادة بشكل دائم. لا يمكن التراجع عن هذه الخطوة.',
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
