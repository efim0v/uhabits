// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class L10nTr extends L10n {
  L10nTr([String locale = 'tr']) : super(locale);

  @override
  String get overview => 'Genel Bakış';

  @override
  String get appName => 'Loop - Alışkanlık Takip Uygulaması';

  @override
  String get mainActivityTitle => 'Alışkanlıklar';

  @override
  String get actionSettings => 'Ayarlar';

  @override
  String get edit => 'Düzenle';

  @override
  String get delete => 'Sil';

  @override
  String get archive => 'Arşivle';

  @override
  String get unarchive => 'Arşivden Çıkar';

  @override
  String get addHabit => 'Alışkanlık ekle';

  @override
  String get colorPickerDefaultTitle => 'Renk Değiştir';

  @override
  String get toastHabitCreated => 'Alışkanlık oluşturuldu.';

  @override
  String get habitStrength => 'Alışkanlık gücü';

  @override
  String get history => 'Geçmiş';

  @override
  String get clear => 'Temizle';

  @override
  String get reminder => 'Hatırlatma';

  @override
  String get save => 'Kaydet';

  @override
  String get streaks => 'Seriler';

  @override
  String get noHabitsFound => 'Etkin alışkanlığın yok';

  @override
  String get noHabitsLeftToDo => 'Bugünlük bu kadar!';

  @override
  String get longPressToToggle =>
      'İşaretlemek veya işareti kaldırmak için basılı tut';

  @override
  String get reminderOff => 'Kapalı';

  @override
  String get createHabit => 'Alışkanlık oluştur';

  @override
  String get editHabit => 'Alışkanlığı düzenle';

  @override
  String get check => 'İşaretle';

  @override
  String get snooze => 'Sonra';

  @override
  String get introTitle1 => 'Hoşgeldin';

  @override
  String get introDescription1 =>
      'Loop Alışkanlık Takibi, iyi alışkanlıklar edinmene ve sürdürmene yardımcı olur.';

  @override
  String get introTitle2 => 'Yeni alışkanlıklar oluştur';

  @override
  String get introDescription2 =>
      'Alışkanlığın gerçekleştiği günleri işaretle.';

  @override
  String get introTitle4 => 'Gelişimini takip et';

  @override
  String get introDescription4 =>
      'Ayrıntılı tablolarla katettiğin ilerlemeyi gör.';

  @override
  String get interval15Minutes => '15 dakika';

  @override
  String get interval30Minutes => '30 dakika';

  @override
  String get interval1Hour => '1 saat';

  @override
  String get interval2Hour => '2 saat';

  @override
  String get interval4Hour => '4 saat';

  @override
  String get interval8Hour => '8 saat';

  @override
  String get interval24Hour => '24 saat';

  @override
  String get intervalAlwaysAsk => 'Her zaman sor';

  @override
  String get intervalCustom => 'Özel...';

  @override
  String get prefToggleTitle => 'Tek dokunuşla işaretle';

  @override
  String get prefToggleDescription2 =>
      'Basılı tutma yerine tek bir dokunuşla onay işaretleri koy.';

  @override
  String get prefRateThisApp => 'Google Play\'de uygulamayı oyla';

  @override
  String get prefSendFeedback => 'Geliştiriciye geri bildirim gönder';

  @override
  String get prefViewSourceCode => 'Github\'da kaynak kodunu görüntüle';

  @override
  String get links => 'Bağlantılar';

  @override
  String get name => 'Alışkanlık ismi';

  @override
  String get settings => 'Ayarlar';

  @override
  String get selectSnoozeDelay => 'Erteleme süresini ayarla';

  @override
  String get hintTitle => 'Biliyor muydun?';

  @override
  String get hintDrag =>
      'Girdileri sıralamak için, alışkanlık adının üstüne basılı tut ve doğru yere sürükle.';

  @override
  String get hintLandscape =>
      'Daha fazla gün görüntülemek için cihazını yatay tut.';

  @override
  String get habitNotFound => 'Alışkanlık silinmiş ya da bulunamadı';

  @override
  String get weekends => 'Hafta sonları';

  @override
  String get anyWeekday => 'Pazartesinden Cumaya';

  @override
  String get anyDay => 'Haftanın herhangi bir günü';

  @override
  String get selectWeekdays => 'Günleri seç';

  @override
  String get exportToCsv => 'CSV olarak dışa aktar';

  @override
  String get doneLabel => 'Seç';

  @override
  String get clearLabel => 'Temizle';

  @override
  String get selectHours => 'Saat seç';

  @override
  String get selectMinutes => 'Dakika seç';

  @override
  String get about => 'Hakkında';

  @override
  String get translators => 'Çevirmenler';

  @override
  String get developers => 'Geliştiriciler';

  @override
  String versionN(String p1) {
    return 'Sürüm $p1';
  }

  @override
  String get frequency => 'Sıklık';

  @override
  String get checkmark => 'Yapıldı işareti';

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
  String get bestStreaks => 'En iyi seriler';

  @override
  String get everyDay => 'Her gün';

  @override
  String get everyWeek => 'Her hafta';

  @override
  String get help => 'Yardım & SSS';

  @override
  String get couldNotExport => 'Dışarı veri aktarımı başarısız.';

  @override
  String get couldNotImport => 'İçeri veri aktarımı başarısız.';

  @override
  String get fileNotRecognized => 'Dosya tanınamadı.';

  @override
  String get habitsImported => 'Alışkanlıklar başarıyla içeri aktarıldı.';

  @override
  String get importData => 'İçeri veri aktar';

  @override
  String get exportFullBackup => 'Tüm yedeği dışarı aktar';

  @override
  String get importDataSummary =>
      'Loop tarafından oluşturulan yedeklemelerin yanı sıra Tickmate, HabitBull veya Rewire tarafından oluşturulan yedeklemeler da desteklenir. Detaylı bilgi için SSS bölümüne bak.';

  @override
  String get exportAsCsvSummary =>
      'Microsoft Excel veya OpenOffice Calc. tarafından açılabilen bir dosya oluşturur. Bu dosya tekrar içeri aktarılamaz.';

  @override
  String get exportFullBackupSummary =>
      'Tüm verilerini içeren bir dosya oluştur. Bu dosya tekrar içeri aktarılabilir.';

  @override
  String get selectPublicBackupFolder => 'Genel yedekleme klasörünü seç';

  @override
  String get noPublicBackupFolderSelected => 'Klasör seçilmedi';

  @override
  String get bugReportFailed => 'Hata raporu oluşturulamadı.';

  @override
  String get generateBugReport => 'Hata raporu oluştur';

  @override
  String get troubleshooting => 'Sorun Giderme';

  @override
  String get helpTranslate => 'Bu uygulamanın çevirisinde yardım et';

  @override
  String get nightMode => 'Gece modu';

  @override
  String get usePureBlack => 'Gece modunda saf siyah kullan';

  @override
  String get pureBlackDescription =>
      'Gece modunda gri arkaplanı saf siyah ile değiştirir. AMOLED ekranlı cihazlarda pil kullanımını azaltır.';

  @override
  String get interfacePreferences => 'Arayüz';

  @override
  String get reverseDays => 'Günleri ters sırala';

  @override
  String get reverseDaysDescription => 'Ana ekranda günleri tersten göster';

  @override
  String get day => 'Gün';

  @override
  String get week => 'Hafta';

  @override
  String get month => 'Ay';

  @override
  String get quarter => '3 Ay';

  @override
  String get year => 'Yıl';

  @override
  String get total => 'Tümü';

  @override
  String get yesOrNo => 'Evet ya da Hayır';

  @override
  String everyXDays(int p1) {
    return 'Her $p1 gün';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Her $p1 hafta';
  }

  @override
  String get score => 'Puan';

  @override
  String get reminderSound => 'Hatırlatma sesi';

  @override
  String get none => 'Sessiz';

  @override
  String get filter => 'Filtre';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Tamamlananları gizle';

  @override
  String get hideEntered => 'Girileni gizle';

  @override
  String get hideArchived => 'Arşivlenenleri gizle';

  @override
  String get stickyNotifications => 'Bildirimleri kalıcı yap';

  @override
  String get stickyNotificationsDescription =>
      'Bildirimlerin kaydırılmasını engeller.';

  @override
  String get ledNotifications => 'Bildirim ışığı';

  @override
  String get ledNotificationsDescription =>
      'Hatırlatıcılar için yanıp sönen bir ışık gösterir. Yalnızca LED bildirim ışığı olan telefonlarda kullanılabilir.';

  @override
  String get repairDatabase => 'Veritabanını onar';

  @override
  String get databaseRepaired => 'Veritabanı onarıldı.';

  @override
  String get uncheck => 'İşareti kaldır';

  @override
  String get toggle => 'Değiştir';

  @override
  String get action => 'Eylem';

  @override
  String get habit => 'Alışkanlık';

  @override
  String get sort => 'Sırala';

  @override
  String get manually => 'Elle';

  @override
  String get byName => 'Ada göre';

  @override
  String get byColor => 'Renge göre';

  @override
  String get byScore => 'Puana göre';

  @override
  String get byStatus => 'Duruma göre';

  @override
  String get export => 'Dışarı aktar';

  @override
  String get longPressToEdit => 'Değeri değiştirmek için basılı tut';

  @override
  String get value => 'Değer';

  @override
  String get calendar => 'Takvim';

  @override
  String get unit => 'Birim';

  @override
  String get targetType => 'Hedef Türü';

  @override
  String get targetTypeAtLeast => 'En az';

  @override
  String get targetTypeAtMost => 'En fazla';

  @override
  String get exampleQuestionBoolean => 'örn: Bugün egzersiz yaptın mı?';

  @override
  String get question => 'Soru';

  @override
  String get target => 'Hedef';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get customizeNotificationSummary =>
      'Ses, titreşim, ışık ve diğer bildirim ayarlarını değiştir';

  @override
  String get customizeNotification => 'Bildirimleri özelleştir';

  @override
  String get prefViewPrivacy => 'Gizlilik politikasını görüntüle';

  @override
  String get viewAllContributors => 'Katkıda bulunanları görüntüle…';

  @override
  String get database => 'Veritabanı';

  @override
  String get widgetOpacityTitle => 'Widget saydamlığı';

  @override
  String get widgetOpacityDescription =>
      'Ana ekrandaki widget\'ları daha saydam veya daha opak hâle getir.';

  @override
  String get firstDayOfTheWeek => 'Haftanın ilk günü';

  @override
  String get defaultReminderQuestion => 'Bugün bu alışkanlığı tamamladın mı?';

  @override
  String get notes => 'Notlar';

  @override
  String get exampleNotes => '(isteğe bağlı)';

  @override
  String get yesOrNoExample =>
      'örn: Bugün erken kalktın mı? Egzersiz yaptın mı? Satranç oynadın mı?';

  @override
  String get measurable => 'Ölçülebilir';

  @override
  String get measurableExample =>
      'örn: Bugün kaç km koştun? Bugün kaç sayfa kitap okudun?';

  @override
  String xTimesPerWeek(int p1) {
    return 'Haftada $p1 kez';
  }

  @override
  String xTimesPerMonth(int p1) {
    return 'Ayda $p1 kez';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 defa / $p2 gün';
  }

  @override
  String get yesOrNoShortExample => 'örn: Egzersiz';

  @override
  String get color => 'Renk';

  @override
  String get exampleTarget => 'örn: 15';

  @override
  String get measurableShortExample => 'örn: Kitap';

  @override
  String get measurableQuestionExample => 'örn: Bugün kaç sayfa kitap okudun?';

  @override
  String get measurableUnitsExample => 'örn: Sayfa';

  @override
  String get everyMonth => 'Her ay';

  @override
  String get validationCannotBeBlank => 'Boş bırakılamaz';

  @override
  String get today => 'Bugün';

  @override
  String get enter => 'Değer gir';

  @override
  String get noHabits => 'Alışkanlık bulunamadı';

  @override
  String get noNumericalHabits => 'Ölçülebilir alışkanlık bulunamadı';

  @override
  String get noBooleanHabits => 'İşaretlemeli alışkanlık bulunamadı';

  @override
  String get increment => 'Artış';

  @override
  String get decrement => 'Azalma';

  @override
  String get prefSkipTitle => 'Gün atlama özelliğini etkinleştir';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Gün atlamak için ikinci kez işaretleme yapın. Atlanmış günler puanınızı etkilemez ve serinizi bozmaz.';

  @override
  String get prefUnknownTitle => 'Eksik verileri soru işaretiyle göster';

  @override
  String get prefUnknownDescription =>
      'Eksik verilerle boş günleri ayırt etmenizde yardımcı olur. Boş gün girmek için iki kere işaretleme yapın.';

  @override
  String get youAreNowADeveloper => 'Artık bir geliştiricisin';

  @override
  String get activityNotFound =>
      'Bu işlemi gerçekleştirebilecek bir uygulama bulunamadı.';

  @override
  String get prefMidnightDelayTitle =>
      'Yeni günü gece yarısından birkaç saat sonra başlat';

  @override
  String get prefMidnightDelayDescription =>
      'Yeni gün saat 03:00\'ten sonra başlar. Geç saatlerde uyuyanlar için kullanışlıdır. Uygulamanın yeniden başlatılmasını gerektirir.';

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
      other: 'Alışkanlıklar değiştirildi',
      one: 'Alışkanlık değiştirildi',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alışkanlıklar silindi',
      one: 'Alışkanlık silindi',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alışkanlıklar arşivlendi',
      one: 'Alışkanlık arşivlendi',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alışkanlıklar arşivden çıkarıldı',
      one: 'Alışkanlık arşivden çıkarıldı',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alışkanlıklar silinsin mi?',
      one: 'Alışkanlık silinsin mi?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alışkanlıklar kalıcı olarak silinecek. Bu işlem geri alınamaz.',
      one: 'Alışkanlık kalıcı olarak silinecek. Bu işlem geri alınamaz.',
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
}
