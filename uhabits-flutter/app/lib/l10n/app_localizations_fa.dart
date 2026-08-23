// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class L10nFa extends L10n {
  L10nFa([String locale = 'fa']) : super(locale);

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'عادت‌ها';

  @override
  String get actionSettings => 'تنظیمات';

  @override
  String get edit => 'ویرایش';

  @override
  String get delete => 'حذف';

  @override
  String get archive => 'بایگانی کردن';

  @override
  String get unarchive => 'خارج کردن از بایگانی';

  @override
  String get addHabit => 'افزودن عادت';

  @override
  String get colorPickerDefaultTitle => 'تغییر رنگ';

  @override
  String get toastHabitCreated => 'عادت ایجاد شد';

  @override
  String get overview => 'مرور';

  @override
  String get habitStrength => 'قدرت عادت';

  @override
  String get history => 'تاریخچه';

  @override
  String get clear => 'پاک کردن';

  @override
  String get reminder => 'یادآوری';

  @override
  String get save => 'ذخیره';

  @override
  String get streaks => 'استمرارها';

  @override
  String get noHabitsFound => 'شما هیچ عادت فعالی ندارید';

  @override
  String get noHabitsLeftToDo =>
      'شما همه موارد مربوط به امروز را انجام داده‌اید!';

  @override
  String get longPressToToggle =>
      'برای تیک زدن یا برداشتن، تپ کنید و نگه دارید';

  @override
  String get reminderOff => 'غیرفعال';

  @override
  String get createHabit => 'ساخت عادت جدید';

  @override
  String get editHabit => 'ویرایش عادت';

  @override
  String get check => 'تیک زدن';

  @override
  String get snooze => 'بعداً';

  @override
  String get introTitle1 => 'خوش آمدید';

  @override
  String get introDescription1 =>
      'عادت‌سنج لوپ به شما کمک می‌کند تا برای خودتان عادت‌های خوبی بسازید.';

  @override
  String get introTitle2 => 'ساخت چند عادت جدید';

  @override
  String get introDescription2 =>
      'هر روز بعد از انجام عادت، آن را در برنامه تیک بزنید.';

  @override
  String get introTitle4 => 'پیشرفت خود را پیگیری کنید';

  @override
  String get introDescription4 =>
      'نمودار جزئیات به شما نشان می‌دهد که چطور عادت‌هایتان با گذشت زمان بهبود پیدا کرده‌اند.';

  @override
  String get interval15Minutes => '۱۵ دقیقه';

  @override
  String get interval30Minutes => '۳۰ دقیقه';

  @override
  String get interval1Hour => '۱ ساعت';

  @override
  String get interval2Hour => '۲ ساعت';

  @override
  String get interval4Hour => '۴ ساعت';

  @override
  String get interval8Hour => '۸ ساعت';

  @override
  String get interval24Hour => '۲۴ ساعت';

  @override
  String get intervalAlwaysAsk => 'همیشه پرسیده شود';

  @override
  String get intervalCustom => 'سفارشی‌سازی';

  @override
  String get prefToggleTitle => 'با اشاره‌ی کوتاه‌مدت وضعیت عادت را تغییر بده';

  @override
  String get prefToggleDescription2 =>
      'به جای فشار دادن و نگه‌داشتن، با یک ضربه تیک بزنید.';

  @override
  String get prefRateThisApp => 'به این برنامه در گوگل‌پلی امتیاز بدهید';

  @override
  String get prefSendFeedback => 'ارسال بازخورد به توسعه‌دهنده';

  @override
  String get prefViewSourceCode => 'دیدن منبع برنامه در گیت‌هاب';

  @override
  String get links => 'پیوند‌ها';

  @override
  String get name => 'نام';

  @override
  String get settings => 'تنظیمات';

  @override
  String get selectSnoozeDelay => 'تأخیر تعویق را انتخاب کنید';

  @override
  String get hintTitle => 'آیا می‌دانستید؟';

  @override
  String get hintDrag =>
      'برای جابجایی عناوین، انگشتتان را روی نام عادت مورد نظر بگذارید و نگه دارید، سپس آن را به محل صحیح بکشید.';

  @override
  String get hintLandscape =>
      'با قرار دادن گوشی در حالت افقی می‌توانید روزهای بیشتری را ببینید.';

  @override
  String get habitNotFound => 'عادت حذف شده / پیدا نشد';

  @override
  String get weekends => 'آخر هفته‌ها';

  @override
  String get anyWeekday => 'دوشنبه تا جمعه';

  @override
  String get anyDay => 'هر روز هفته';

  @override
  String get selectWeekdays => 'انتخاب روزها';

  @override
  String get exportToCsv => 'خروجی فایل CSV';

  @override
  String get doneLabel => 'انجام شد';

  @override
  String get clearLabel => 'پاک کردن';

  @override
  String get selectHours => 'انتخاب ساعت';

  @override
  String get selectMinutes => 'انتخاب دقیقه';

  @override
  String get about => 'درباره';

  @override
  String get translators => 'مترجمان';

  @override
  String get developers => 'توسعه‌دهندگان';

  @override
  String versionN(String p1) {
    return 'نسخه $p1';
  }

  @override
  String get frequency => 'تناوب‌';

  @override
  String get checkmark => 'علامت';

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
  String get bestStreaks => 'بهترین استمرار';

  @override
  String get everyDay => 'هر روز';

  @override
  String get everyWeek => 'هر هفته';

  @override
  String get help => 'راهنما و سوالات متداول';

  @override
  String get couldNotExport => 'خطا در خروجی گرفتن از دیتا.';

  @override
  String get couldNotImport => 'خطا در وارد کردن دیتا.';

  @override
  String get fileNotRecognized => 'فایل شناخته شده نیست.';

  @override
  String get habitsImported => 'عادت‌ها با موفقیت وارد شدند.';

  @override
  String get importData => 'وارد کردن دیتا';

  @override
  String get exportFullBackup => 'پشتیبان‌گیری کامل';

  @override
  String get importDataSummary =>
      'علاوه بر پشتیبان کامل تهیه شده توسط این برنامه، از پرونده‌های تولید شده توسط Tickmate، HabitbBull و یا Rewire هم پشتیبانی می‌شود. برای اطلاعات بیشتر سوالات متداول را ببینید.';

  @override
  String get exportAsCsvSummary =>
      'پرونده‌ای تولید می‌کند که می‌توان توسط برنامه‌های صفحه گسترده مانند Microsoft Excel و یا OpenOffice Calc بازشان کرد. این پرونده قابلیت وارد کردن مجدد به این برنامه را ندارد.';

  @override
  String get exportFullBackupSummary =>
      'پرونده‌ای تولید می‌کند که شامل تمام اطلاعات شما است. این پرونده قابل بازیابی توسط این برنامه می‌باشد.';

  @override
  String get selectPublicBackupFolder => 'انتخاب پوشهٔ پشتیبان‌گیری عمومی';

  @override
  String get noPublicBackupFolderSelected => 'هیچ پوشه‌ای انتخاب نشده است';

  @override
  String get bugReportFailed => 'خطایی در تولید گزارش مشکلات بوجود آمد.';

  @override
  String get generateBugReport => 'ایجاد گزارش مشکلات';

  @override
  String get troubleshooting => 'ایرادیابی';

  @override
  String get helpTranslate => 'کمک برای ترجمه این برنامه';

  @override
  String get nightMode => 'حالت تیره';

  @override
  String get usePureBlack => 'استفاده از رنگ سیاه خالص در حالت تیره';

  @override
  String get pureBlackDescription =>
      'جایگزینی پس‌زمینه خاکستری با سیاه خالص در حالت تیره. استفاده از باتری را در گوشی‌های با صفحه نمایش AMOLED کاهش می‌دهد.';

  @override
  String get interfacePreferences => 'رابط کاربری';

  @override
  String get reverseDays => 'معکوس کردن ترتیب روزها';

  @override
  String get reverseDaysDescription =>
      'روزها را در صفحه اصلی با ترتیب معکوس نمایش می‌دهد.';

  @override
  String get day => 'روز';

  @override
  String get week => 'هفته';

  @override
  String get month => 'ماه';

  @override
  String get quarter => 'فصل';

  @override
  String get year => 'سال';

  @override
  String get total => 'مجموع';

  @override
  String get yesOrNo => 'بله یا خیر';

  @override
  String everyXDays(int p1) {
    return 'هر $p1 روز یک‌بار';
  }

  @override
  String everyXWeeks(int p1) {
    return 'هر $p1 هفته یک‌بار';
  }

  @override
  String get score => 'امتیاز';

  @override
  String get reminderSound => 'صدای یادآور';

  @override
  String get none => 'هیچ‌کدام';

  @override
  String get filter => 'فیلتر';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'مخفی کردن کامل‌شده‌ها';

  @override
  String get hideEntered => 'پنهان کردن مقادیر';

  @override
  String get hideArchived => 'مخفی کردن بایگانی‌شده‌ها';

  @override
  String get stickyNotifications => 'چسبناک کردن اعلان‌ها';

  @override
  String get stickyNotificationsDescription =>
      'از رد کردن اعلان با کشیدن جلوگیری می‌کند.';

  @override
  String get ledNotifications => 'چراغ اعلان';

  @override
  String get ledNotificationsDescription =>
      'یک چراغ چشمک‌زن برای یادآوری‌ها نشان می‌دهد. فقط در گوشی‌های دارای چراغ‌های اعلان LED موجود است.';

  @override
  String get repairDatabase => 'تعمیر دیتابیس';

  @override
  String get databaseRepaired => 'دیتابیس تعمیر شد.';

  @override
  String get uncheck => 'برداشتن تیک';

  @override
  String get toggle => 'تغییر وضعیت';

  @override
  String get action => 'اقدام';

  @override
  String get habit => 'عادت';

  @override
  String get sort => 'مرتب‌سازی';

  @override
  String get manually => 'دستی';

  @override
  String get byName => 'براساس نام';

  @override
  String get byColor => 'براساس رنگ';

  @override
  String get byScore => 'براساس امتیاز';

  @override
  String get byStatus => 'براساس وضعیت';

  @override
  String get export => 'خروجی گرفتن';

  @override
  String get longPressToEdit => 'فشار دهید و نگه دارید تا مقدار را تغییر دهید';

  @override
  String get value => 'مقدار';

  @override
  String get calendar => 'تقویم';

  @override
  String get unit => 'واحد';

  @override
  String get targetType => 'نوع داده هدف';

  @override
  String get targetTypeAtLeast => 'حداقل';

  @override
  String get targetTypeAtMost => 'حداکثر';

  @override
  String get exampleQuestionBoolean => 'مثلا آیا امروز ورزش کردید؟';

  @override
  String get question => 'سوال';

  @override
  String get target => 'هدف';

  @override
  String get yes => 'بله';

  @override
  String get no => 'نه';

  @override
  String get customizeNotificationSummary =>
      'صدا، لرزش، نور و سایر تنظیمات را تغییر دهید';

  @override
  String get customizeNotification => 'اعلان‌ها را سفارشی‌سازی کنید';

  @override
  String get prefViewPrivacy => 'مشاهده سیاست حفظ حریم خصوصی';

  @override
  String get viewAllContributors => 'مشاهده همه همکاران&#8230;';

  @override
  String get database => 'دیتابیس';

  @override
  String get widgetOpacityTitle => 'تیرگی ویجت';

  @override
  String get widgetOpacityDescription =>
      'ویجت‌ها را در صفحه اصلی شفاف‌تر یا مات‌تر می‌کند.';

  @override
  String get firstDayOfTheWeek => 'روز اول هفته';

  @override
  String get defaultReminderQuestion => 'آیا امروز این عادت را انجام داده‌اید؟';

  @override
  String get notes => 'یادداشت‌ها';

  @override
  String get exampleNotes => '(اختیاری)';

  @override
  String get yesOrNoExample =>
      'آیا امروز زود بیدار شدید؟ ورزش کردید؟ شطرنج بازی کردید؟';

  @override
  String get measurable => 'قابل اندازه‌گیری';

  @override
  String get measurableExample =>
      'مثلاً امروز چند کیلومتر دویدید؟ چند صفحه مطالعه کردید؟';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 بار در هفته';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 بار در ماه';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 بار در هر $p2 روز';
  }

  @override
  String get yesOrNoShortExample => 'مثلاً ورزش کنید';

  @override
  String get color => 'رنگ';

  @override
  String get exampleTarget => 'مثلاً 15';

  @override
  String get measurableShortExample => 'مثلاً دویدن';

  @override
  String get measurableQuestionExample => 'مثلاً امروز چند کیلومتر دویدید؟';

  @override
  String get measurableUnitsExample => 'مثلاً کیلومتر';

  @override
  String get everyMonth => 'هر ماه';

  @override
  String get validationCannotBeBlank => 'نمی‌تواند خالی باشد';

  @override
  String get today => 'امروز';

  @override
  String get enter => 'وارد کردن';

  @override
  String get noHabits => 'عادتی یافت نشد';

  @override
  String get noNumericalHabits => 'عادت قابل‌اندازه‌گیری یافت نشد';

  @override
  String get noBooleanHabits => 'عادت بله/خیر یافت نشد';

  @override
  String get increment => 'افزایش';

  @override
  String get decrement => 'کاهش';

  @override
  String get prefSkipTitle => 'فعال کردن پریدن از روزها';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'دو بار تپ کنید تا به جای تیک زدن، از آن روز بپرید. پریدن از یک روز، امتیاز شما را دست‌نخورده نگه‌می‌دارد و استمرار عادت را خراب نمی‌کند.';

  @override
  String get prefUnknownTitle =>
      'نمایش علامت سوال برای مواردی که دیتایی وجود ندارد';

  @override
  String get prefUnknownDescription =>
      'روزهایی که دیتا ندارند و آن‌هایی که از رویشان پریده‌اید را متفاوت نشان می‌دهد. برای پریدن از روی یک روز، دو بار روی آن تپ کنید.';

  @override
  String get youAreNowADeveloper => 'شما اکنون یک توسعه‌دهنده هستید';

  @override
  String get activityNotFound => 'هیچ برنامه‌ای برای انجام این کار یافت نشد.';

  @override
  String get prefMidnightDelayTitle =>
      'تمدید کردن روز تا چند ساعت بعد از نیمه‌شب';

  @override
  String get prefMidnightDelayDescription =>
      'تا ساعت ۳ نیمه‌شب برای نمایش یک روز جدید صبر می‌کند. اگر معمولاً بعد از نیمه‌شب می‌خوابید، برای شما می‌تواند مفید باشد. نیازمند راه‌اندازی مجدد برنامه است.';

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
      other: 'عادت‌ها تغییر داده شدند',
      one: 'عادت تغییر داده شد',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عادت‌ها حذف شدند.',
      one: 'عادت حذف شد.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عادت‌ها بایگانی شدند.',
      one: 'عادت بایگانی شد.',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عادت‌ها از بایگانی خارج شدند.',
      one: 'عادت از بایگانی خارج شد.',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف عادت‌ها؟',
      one: 'حذف عادت؟',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'این عادت‌ها برای همیشه حذف خواهند شد و قابل بازیابی نخواهند بود.',
      one: 'این عادت برای همیشه حذف خواهد شد و قابل بازیابی نخواهد بود.',
    );
    return '$_temp0';
  }
}
