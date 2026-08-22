// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class L10nId extends L10n {
  L10nId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'Loop Habit Tracker';

  @override
  String get mainActivityTitle => 'Kebiasaan';

  @override
  String get actionSettings => 'Pengaturan';

  @override
  String get edit => 'Ubah';

  @override
  String get delete => 'Hapus';

  @override
  String get archive => 'Arsip';

  @override
  String get unarchive => 'Keluarkan dari arsip';

  @override
  String get addHabit => 'Tambah Kebiasaan';

  @override
  String get colorPickerDefaultTitle => 'Ganti warna';

  @override
  String get toastHabitCreated => 'Kebiasaan ditambahkan';

  @override
  String get habitStrength => 'Kekuatan Kebiasaan';

  @override
  String get history => 'Riwayat';

  @override
  String get clear => 'Bersihkan';

  @override
  String get reminder => 'Pengingat';

  @override
  String get save => 'Simpan';

  @override
  String get streaks => 'Rentetan';

  @override
  String get noHabitsFound => 'Kamu tidak memiliki Kebiasaan yang aktif';

  @override
  String get noHabitsLeftToDo => 'Kamu sudah selesai untuk hari ini!';

  @override
  String get longPressToToggle =>
      'Tekan dan tahan untuk menambah atau menghapus centang';

  @override
  String get reminderOff => 'Mati';

  @override
  String get createHabit => 'Buat Kebiasaan';

  @override
  String get editHabit => 'Edit Kebiasaan';

  @override
  String get check => 'Centang';

  @override
  String get snooze => 'Tunda';

  @override
  String get introTitle1 => 'Selamat datang';

  @override
  String get introDescription1 =>
      'Loop Habit Tracker membantu menciptakan dan memelihara Kebiasaan baikmu.';

  @override
  String get introTitle2 => 'Buat beberapa Kebiasaan baru';

  @override
  String get introDescription2 =>
      'Berikan tanda centang setiap kali kamu selesai melakukannya.';

  @override
  String get introTitle4 => 'Lacak perkembanganmu';

  @override
  String get introDescription4 =>
      'Grafik terperinci menampilkan perkembangan Kebiasaanmu dari waktu ke waktu.';

  @override
  String get interval15Minutes => '15 menit';

  @override
  String get interval30Minutes => '30 menit';

  @override
  String get interval1Hour => '1 jam';

  @override
  String get interval2Hour => '2 jam';

  @override
  String get interval4Hour => '4 jam';

  @override
  String get interval8Hour => '8 jam';

  @override
  String get interval24Hour => '24 jam';

  @override
  String get intervalAlwaysAsk => 'Selalu bertanya';

  @override
  String get intervalCustom => 'Kustom...';

  @override
  String get prefToggleTitle => 'Tandai dengan cepat';

  @override
  String get prefToggleDescription2 =>
      'Beri tanda centang dengan satu ketukan alih-alih tekan-dan-tahan.';

  @override
  String get prefRateThisApp => 'Berikan rating aplikasi ini di Google Play';

  @override
  String get prefSendFeedback => 'Kirimkan umpan balik kepada Developer';

  @override
  String get prefViewSourceCode => 'Lihat kode program di GitHub';

  @override
  String get links => 'Tautan';

  @override
  String get name => 'Nama';

  @override
  String get settings => 'Pengaturan';

  @override
  String get selectSnoozeDelay => 'Pilih jeda penundaan';

  @override
  String get hintTitle => 'Tahukah kamu?';

  @override
  String get hintDrag =>
      'Untuk mengatur urutan, tekan dan tahan judul Kebiasaan lalu tempatkan pada posisi yang kamu inginkan.';

  @override
  String get hintLandscape =>
      'Kamu bisa melihat lebih banyak hari dengan mengubah posisi ponsel menjadi mode landscape.';

  @override
  String get habitNotFound => 'Kebiasaan telah dihapus / tidak ditemukan';

  @override
  String get weekends => 'Akhir pekan';

  @override
  String get anyWeekday => 'Senin - Jumat';

  @override
  String get anyDay => 'Hari apapun dalam satu minggu';

  @override
  String get selectWeekdays => 'Pilih hari';

  @override
  String get exportToCsv => 'Ekspor sebagai CSV';

  @override
  String get doneLabel => 'Selesai';

  @override
  String get clearLabel => 'Hapus';

  @override
  String get selectHours => 'Pilih jam';

  @override
  String get selectMinutes => 'Pilih menit';

  @override
  String get about => 'Tentang';

  @override
  String get translators => 'Penerjemah';

  @override
  String get developers => 'Developer';

  @override
  String versionN(String p1) {
    return 'Versi $p1';
  }

  @override
  String get frequency => 'Frekuensi';

  @override
  String get checkmark => 'Tanda centang';

  @override
  String get checkmarkStackWidget => 'Widget susunan tanda centang';

  @override
  String get frequencyStackWidget => 'Widget susunan frekuensi';

  @override
  String get scoreStackWidget => 'Widget susunan skor';

  @override
  String get historyStackWidget => 'Widget sususan riwayat';

  @override
  String get streaksStackWidget => 'Widget susunan rentetan';

  @override
  String get bestStreaks => 'Rentetan terbaik';

  @override
  String get everyDay => 'Setiap hari';

  @override
  String get everyWeek => 'Setiap minggu';

  @override
  String get help => 'Bantuan & FAQ';

  @override
  String get couldNotExport => 'Gagal mengekspor data.';

  @override
  String get couldNotImport => 'Gagal mengimpor data.';

  @override
  String get fileNotRecognized => 'File tidak dikenali.';

  @override
  String get habitsImported => 'Impor data Kebiasaan berhasil.';

  @override
  String get importData => 'Impor data';

  @override
  String get exportFullBackup => 'Ekspor cadangan secara keseluruhan';

  @override
  String get importDataSummary =>
      'Mendukung ekspor data dan file dari aplikasi Tickmate, HabitBull atau Rewire. Lihat FAQ untuk informasi lebih lanjut.';

  @override
  String get exportAsCsvSummary =>
      'Menghasilkan file yang bisa dibuka menggunakan aplikasi seperti Microsoft Excel atau OpenOffice Calc. File ini tidak bisa diimpor kembali.';

  @override
  String get exportFullBackupSummary =>
      'Menghasilkan file yang berisi seluruh datamu. File ini bisa diimpor kembali.';

  @override
  String get selectPublicBackupFolder => 'Pilih folder cadangan publik';

  @override
  String get noPublicBackupFolderSelected => 'Tidak ada folder yang dipilih';

  @override
  String get bugReportFailed => 'Gagal membuat laporan masalah.';

  @override
  String get generateBugReport => 'Membuat laporan masalah';

  @override
  String get troubleshooting => 'Troubleshoot';

  @override
  String get helpTranslate => 'Bantu menerjemahkan aplikasi ini';

  @override
  String get nightMode => 'Mode malam';

  @override
  String get usePureBlack => 'Gunakan warna hitam pekat pada mode malam';

  @override
  String get pureBlackDescription =>
      'Ganti warna latar abu-abu dengan warna hitam pada mode malam. Mengurangi penggunaan baterai pada layar AMOLED.';

  @override
  String get interfacePreferences => 'Antarmuka';

  @override
  String get reverseDays => 'Balik urutan hari';

  @override
  String get reverseDaysDescription =>
      'Tampilkan hari dalam urutan terbalik pada layar utama.';

  @override
  String get day => 'Hari';

  @override
  String get week => 'Minggu';

  @override
  String get month => 'Bulan';

  @override
  String get quarter => 'Kuartal';

  @override
  String get year => 'Tahun';

  @override
  String get total => 'Total';

  @override
  String get yesOrNo => 'Ya atau Tidak';

  @override
  String everyXDays(int p1) {
    return 'Setiap $p1 hari';
  }

  @override
  String everyXWeeks(int p1) {
    return 'Setiap $p1 minggu';
  }

  @override
  String get score => 'Skor';

  @override
  String get reminderSound => 'Suara pengingat';

  @override
  String get none => 'Tidak ada';

  @override
  String get filter => 'Filter';

  @override
  String get search => 'Search';

  @override
  String get hideCompleted => 'Sembunyikan yang selesai';

  @override
  String get hideEntered => 'Sembunyikan yang dimasukkan';

  @override
  String get hideArchived => 'Sembunyikan yang diarsipkan';

  @override
  String get stickyNotifications => 'Jadikan notifikasi melekat';

  @override
  String get stickyNotificationsDescription =>
      'Mencegah notifikasi untuk terhapus.';

  @override
  String get ledNotifications => 'Lampu Notifikasi';

  @override
  String get ledNotificationsDescription =>
      'Memperlihatkan lampu yang berkedip sebagai pengingat. Hanya tersedia di perangkat dengan lampu notifikasi LED.';

  @override
  String get repairDatabase => 'Perbaiki basis data';

  @override
  String get databaseRepaired => 'Basis data diperbaiki.';

  @override
  String get uncheck => 'Hapus centang';

  @override
  String get toggle => 'Toggle';

  @override
  String get action => 'Tindakan';

  @override
  String get habit => 'Kebiasaan';

  @override
  String get sort => 'Urutkan';

  @override
  String get manually => 'Secara manual';

  @override
  String get byName => 'Berdasarkan nama';

  @override
  String get byColor => 'Berdasarkan warna';

  @override
  String get byScore => 'Berdasarkan skor';

  @override
  String get byStatus => 'Berdasarkan status';

  @override
  String get export => 'Ekspor';

  @override
  String get longPressToEdit => 'Tekan-dan-tahan untuk mengubah nilai';

  @override
  String get value => 'Nilai';

  @override
  String get calendar => 'Kalender';

  @override
  String get unit => 'Unit';

  @override
  String get targetType => 'Jenis Target';

  @override
  String get targetTypeAtLeast => 'Paling sedikit';

  @override
  String get targetTypeAtMost => 'Paling banyak';

  @override
  String get exampleQuestionBoolean =>
      'mis. Apakah kamu sudah berolahraga hari ini?';

  @override
  String get question => 'Pertanyaan';

  @override
  String get target => 'Target';

  @override
  String get yes => 'Ya';

  @override
  String get no => 'Tidak';

  @override
  String get customizeNotificationSummary =>
      'Ubah suara, getaran, cahaya, dan pengaturan notifikasi lainnya';

  @override
  String get customizeNotification => 'Sesuaikan notifikasi';

  @override
  String get prefViewPrivacy => 'Lihat Kebijakan Privasi';

  @override
  String get viewAllContributors => 'Lihat semua kontributor';

  @override
  String get database => 'Basis data';

  @override
  String get widgetOpacityTitle => 'Opasitas widget';

  @override
  String get widgetOpacityDescription =>
      'Menjadikan widget lebih transparan atau lebih pekat di layar berandamu.';

  @override
  String get firstDayOfTheWeek => 'Hari pertama dalam seminggu';

  @override
  String get defaultReminderQuestion =>
      'Sudahkah kamu menyelesaikan kebiasaan ini hari ini?';

  @override
  String get notes => 'Catatan';

  @override
  String get exampleNotes => '(Opsional)';

  @override
  String get yesOrNoExample =>
      'mis. Apakah kamu bangun awal hari ini? Apakah kamu sudah berolahraga? Apakah kamu sudah bermain catur?';

  @override
  String get measurable => 'Terukur';

  @override
  String get measurableExample =>
      'mis. Berapa km kamu berlari hari ini? Berapa lembar yang sudah kamu baca?';

  @override
  String xTimesPerWeek(int p1) {
    return '$p1 kali per minggu';
  }

  @override
  String xTimesPerMonth(int p1) {
    return '$p1 kali per bulan';
  }

  @override
  String xTimesPerYDays(int p1, int p2) {
    return '$p1 kali dalam $p2 hari';
  }

  @override
  String get yesOrNoShortExample => 'mis. Olahraga';

  @override
  String get color => 'Warna';

  @override
  String get exampleTarget => 'mis. 15';

  @override
  String get measurableShortExample => 'mis. Lari';

  @override
  String get measurableQuestionExample =>
      'mis. Berapa km kamu berlari hari ini?';

  @override
  String get measurableUnitsExample => 'mis. km';

  @override
  String get everyMonth => 'Setiap bulan';

  @override
  String get validationCannotBeBlank => 'Tidak boleh kosong';

  @override
  String get today => 'Hari ini';

  @override
  String get enter => 'Enter';

  @override
  String get noHabits => 'Tidak ada Kebiasaan ditemukan';

  @override
  String get noNumericalHabits => 'Tidak ada Kebiasaan terukur yang ditemukan';

  @override
  String get noBooleanHabits =>
      'Tidak ada Kebiasaan ya-atau-tidak yang ditemukan';

  @override
  String get increment => 'Kenaikan';

  @override
  String get decrement => 'Pengurangan';

  @override
  String get prefSkipTitle => 'Aktifkan lewati hari';

  @override
  String get skipDay => 'Skip';

  @override
  String get prefSkipDescription =>
      'Alihkan dua kali untuk menambahkan sebuah skip, bukannya tanda centang. Skip membuat skormu tidak berubah dan tidak merusak rentetanmu.';

  @override
  String get prefUnknownTitle => 'Tampilkan tanda tanya untuk data yang hilang';

  @override
  String get prefUnknownDescription =>
      'Membedakan hari tanpa data dari selang waktu yang aktual. Untuk memasukkan selang waktu, alihkan dua kali.';

  @override
  String get youAreNowADeveloper => 'Kamu sekarang adalah seorang developer';

  @override
  String get activityNotFound =>
      'Aplikasi untuk mendukung tindakan ini tidak ditemukan';

  @override
  String get prefMidnightDelayTitle =>
      'Perpanjang hari beberapa jam setelah tengah malam';

  @override
  String get prefMidnightDelayDescription =>
      'Tunggu sampai jam 3 pagi untuk menampilkan hari yang baru. Berguna jika kamu biasanya tidur setelah tengah malam. Aplikasi perlu dimulai ulang.';

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
      other: 'Kebiasaan diubah',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kebiasaan dihapus',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsArchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kebiasaan diarsipkan',
    );
    return '$_temp0';
  }

  @override
  String toastHabitsUnarchived(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kebiasaan dikeluarkan dari arsip',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hapus Kebiasaan?',
    );
    return '$_temp0';
  }

  @override
  String deleteHabitsMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Kebiasaan ini akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
    );
    return '$_temp0';
  }
}
